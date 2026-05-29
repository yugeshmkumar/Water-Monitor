# Phase 2A Implementation Guide — AWS Cloud Sync

**Duration:** 3-4 weeks  
**AWS Services:** DynamoDB, RDS, API Gateway, Lambda, SQS, CloudWatch, IAM  
**Team:** 1 backend engineer + device firmware updates + iOS app updates

---

## Part 1: AWS Architecture Setup

### 1.1 Pre-Setup Checklist

```
✅ AWS Account created
✅ AWS CLI installed (`aws --version`)
✅ AWS credentials configured (`aws configure`)
✅ Region selected: us-east-1 (adjust if needed)
✅ IAM user with programmatic access created
✅ VPC ready (use default VPC for now)
```

**Verify setup:**
```bash
aws sts get-caller-identity
# Output should show your AWS account ID
```

### 1.2 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        AWS Account                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              API Layer                               │   │
│  │  ┌──────────────────────────────────────────────┐    │   │
│  │  │ API Gateway (REST + WebSocket)              │    │   │
│  │  │ - POST /api/readings (batch ingest)         │    │   │
│  │  │ - GET /api/readings (historical fetch)      │    │   │
│  │  │ - CRUD /api/profiles/{id}                   │    │   │
│  │  │ - CRUD /api/devices/{id}                    │    │   │
│  │  │ - WebSocket for real-time updates           │    │   │
│  │  └──────────────────────────────────────────────┘    │   │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │                                            │
│        ┌────────┴─────────┬───────────────┐                 │
│        │                  │               │                 │
│  ┌─────▼─────┐    ┌──────▼──────┐   ┌────▼────┐            │
│  │  Lambda   │    │   Lambda    │   │ Lambda  │            │
│  │  Sync     │    │ Dedup       │   │ Insights│            │
│  │ Readings  │    │ & Store     │   │ Engine  │            │
│  └─────┬─────┘    └──────┬──────┘   └────┬────┘            │
│        │                 │               │                  │
│  ┌─────▼──────────────┬──▼─┐        ┌───▼──────┐           │
│  │                    │    │        │          │           │
│  │   DynamoDB        │ SQS│        │  S3      │           │
│  │  (readings)       │    │        │(backups) │           │
│  │                   └────┘        └──────────┘           │
│  │                                                         │
│  │   RDS PostgreSQL                                       │
│  │   - users table                                        │
│  │   - profiles table                                     │
│  │   - devices table                                      │
│  │   - sync_queue table                                  │
│  │   - anomalies table                                   │
│  │   - insights table                                    │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ AWS IoT Core (MQTT Broker)                           │   │
│  │ - tank/{device_id}/reading/live                      │   │
│  │ - tank/{device_id}/config/request                    │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
        ↑                          ↑
        │                          │
    Device (ESP32)            iOS App
    ├─ REST API              ├─ Fetch readings
    ├─ MQTT Pub/Sub          ├─ Sync queue
    └─ WebSocket            └─ Display UI
```

---

## Part 2: Step-by-Step Implementation

### Step 1: DynamoDB Setup (Day 1 Morning)

#### 1.1 Create DynamoDB Table for Readings

```bash
# Set variables
TABLE_NAME="water-monitor-readings"
REGION="us-east-1"

# Create table
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=device_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=device_id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION

# Wait for table to be active
aws dynamodb wait table-exists \
  --table-name $TABLE_NAME \
  --region $REGION
```

#### 1.2 Add Global Secondary Index (for queries)

```bash
aws dynamodb update-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=device_id,AttributeType=S \
    AttributeName=created_at,AttributeType=N \
  --global-secondary-indexes \
    "IndexName=device_created_index,\
     Keys=[{AttributeName=device_id,KeyType=HASH},\
           {AttributeName=created_at,KeyType=RANGE}],\
     Projection={ProjectionType=ALL},\
     ProvisionedThroughput={ReadCapacityUnits=100,WriteCapacityUnits=100}" \
  --region $REGION
```

#### 1.3 Enable TTL (Auto-delete readings after 1 year)

```bash
aws dynamodb update-time-to-live \
  --table-name $TABLE_NAME \
  --time-to-live-specification AttributeName=expires_at,Enabled=true \
  --region $REGION
```

**DynamoDB Item Schema:**
```json
{
  "device_id": "Tank-1",
  "timestamp": 1717077600,  // Unix seconds
  "distance_cm": 35.2,
  "level_pct": 62,
  "sensor_ok": true,
  "is_test": false,
  "is_anomaly": false,
  "anomaly_reason": null,
  "created_at": 1717077603,  // Server time
  "synced_from_app_id": "app-123",
  "expires_at": 1748613600,  // 1 year from creation (for TTL)
  "dedup_key": "Tank-1_1717077600_35.2"  // For dedup checks
}
```

**Cost:** On-demand pricing, typically $1-5/month for Phase 2A

---

### Step 2: RDS PostgreSQL Setup (Day 1 Afternoon)

#### 2.1 Create RDS Instance

```bash
# Create subnet group first
aws rds create-db-subnet-group \
  --db-subnet-group-name water-monitor-subnet \
  --db-subnet-group-description "Water Monitor DB Subnet" \
  --subnet-ids subnet-xxxxx subnet-yyyyy \
  --region us-east-1

# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier water-monitor-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password 'YourSecurePassword123!' \
  --allocated-storage 20 \
  --db-subnet-group-name water-monitor-subnet \
  --vpc-security-group-ids sg-xxxxx \
  --backup-retention-period 7 \
  --enable-iam-database-authentication \
  --region us-east-1

# Wait for instance to be available
aws rds wait db-instance-available \
  --db-instance-identifier water-monitor-postgres \
  --region us-east-1

# Get endpoint
aws rds describe-db-instances \
  --db-instance-identifier water-monitor-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --region us-east-1
```

#### 2.2 Create PostgreSQL Schema

**Save as `schema.sql`:**

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR UNIQUE NOT NULL,
  username VARCHAR UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  subscription_plan VARCHAR DEFAULT 'free'
);

-- Profiles (Water systems)
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  location VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  version INT DEFAULT 1,
  last_modified_by_app_id VARCHAR,
  
  INDEX idx_user_profiles (user_id)
);

-- Devices (Tanks, motors)
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  device_id VARCHAR UNIQUE NOT NULL,  -- "Tank-1"
  type VARCHAR NOT NULL,  -- "tank", "motor", "sensor"
  config JSONB,  -- {empty_cm, full_cm, volume_l, motor_power_w, ...}
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_profile_devices (profile_id),
  INDEX idx_device_id (device_id)
);

-- Sync Queue (Pending reads from app)
CREATE TABLE sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id VARCHAR NOT NULL,
  device_id VARCHAR NOT NULL,
  readings_json JSONB NOT NULL,  -- Array of {device_id, timestamp, distance_cm, ...}
  status VARCHAR DEFAULT 'pending',  -- pending, synced, failed
  attempts INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  synced_at TIMESTAMP,
  
  INDEX idx_status_created (status, created_at),
  INDEX idx_app_device (app_id, device_id)
);

-- Anomalies detected
CREATE TABLE anomalies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR NOT NULL,
  type VARCHAR NOT NULL,  -- leak, motor_inefficiency, sensor_drift
  severity VARCHAR NOT NULL,  -- info, warning, critical
  description TEXT,
  data JSONB,  -- {reading_count, avg_rate, threshold_exceeded_by, ...}
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP,
  
  INDEX idx_device_created (device_id, created_at)
);

-- Daily insights (Pre-computed)
CREATE TABLE insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR NOT NULL,
  period_date DATE NOT NULL,
  avg_level_pct FLOAT,
  min_level_pct INT,
  max_level_pct INT,
  fill_count INT,
  drain_count INT,
  total_usage_l FLOAT,
  peak_hour INT,
  data JSONB,  -- {patterns, anomalies, ...}
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE (device_id, period_date),
  INDEX idx_device_date (device_id, period_date)
);
```

**Apply schema:**
```bash
# Connect to RDS
psql -h water-monitor-postgres.xxxxx.us-east-1.rds.amazonaws.com \
     -U admin \
     -d postgres \
     -f schema.sql
```

**Cost:** db.t3.micro is free tier eligible (12 months), then ~$10-15/month

---

### Step 3: API Gateway + Lambda Setup (Day 2)

#### 3.1 Create IAM Role for Lambda

```bash
# Create trust policy
cat > lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name water-monitor-lambda-role \
  --assume-role-policy-document file://lambda-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name water-monitor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam attach-role-policy \
  --role-name water-monitor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSDataFullAccess

aws iam attach-role-policy \
  --role-name water-monitor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

aws iam attach-role-policy \
  --role-name water-monitor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
```

#### 3.2 Create Lambda Function: Sync Readings

**Save as `lambda_sync_readings.py`:**

```python
import json
import boto3
import hashlib
from datetime import datetime, timedelta
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['READINGS_TABLE'])

def lambda_handler(event, context):
    """
    POST /api/readings
    Body: [
      {
        "device_id": "Tank-1",
        "timestamp": 1717077600,
        "distance_cm": 35.2,
        "level_pct": 62,
        "sensor_ok": true
      },
      ...
    ]
    """
    
    try:
        readings = json.loads(event['body'])
        
        # Validate and store
        synced_ids = []
        conflicts = []
        
        for reading in readings:
            device_id = reading.get('device_id')
            timestamp = reading.get('timestamp')
            distance_cm = reading.get('distance_cm')
            
            # Create dedup key
            dedup_key = f"{device_id}_{timestamp}_{distance_cm}"
            dedup_hash = hashlib.sha256(dedup_key.encode()).hexdigest()
            
            # Check if already exists (dedup)
            try:
                response = table.get_item(
                    Key={
                        'device_id': device_id,
                        'timestamp': timestamp
                    }
                )
                
                if 'Item' in response:
                    # Already exists, skip
                    conflicts.append({
                        'reading_id': dedup_hash,
                        'reason': 'duplicate'
                    })
                    continue
            except Exception as e:
                print(f"Error checking dedup: {e}")
            
            # Store reading
            item = {
                'device_id': device_id,
                'timestamp': int(timestamp),
                'distance_cm': float(reading.get('distance_cm', 0)),
                'level_pct': int(reading.get('level_pct', 0)),
                'sensor_ok': reading.get('sensor_ok', False),
                'is_test': reading.get('is_test', False),
                'created_at': int(datetime.now().timestamp()),
                'synced_from_app_id': event.get('headers', {}).get('X-App-ID', 'unknown'),
                'dedup_key': dedup_hash,
                'expires_at': int((datetime.now() + timedelta(days=365)).timestamp())
            }
            
            try:
                table.put_item(Item=item)
                synced_ids.append(dedup_hash)
            except Exception as e:
                print(f"Error storing reading: {e}")
                conflicts.append({
                    'reading_id': dedup_hash,
                    'reason': f'storage_error: {str(e)}'
                })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'synced_count': len(synced_ids),
                'synced_ids': synced_ids,
                'conflict_count': len(conflicts),
                'conflicts': conflicts
            })
        }
    
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

#### 3.3 Deploy Lambda Function

```bash
# Package function
cd /path/to/lambda_functions
zip sync-readings.zip lambda_sync_readings.py

# Create function
aws lambda create-function \
  --function-name water-monitor-sync-readings \
  --runtime python3.11 \
  --role arn:aws:iam::ACCOUNT_ID:role/water-monitor-lambda-role \
  --handler lambda_sync_readings.lambda_handler \
  --zip-file fileb://sync-readings.zip \
  --environment Variables={READINGS_TABLE=water-monitor-readings} \
  --timeout 30 \
  --memory-size 256

# Get function ARN
aws lambda get-function \
  --function-name water-monitor-sync-readings \
  --query 'Configuration.FunctionArn'
```

#### 3.4 Create API Gateway

```bash
# Create API
API_ID=$(aws apigateway create-rest-api \
  --name water-monitor-api \
  --description "Water Monitor Cloud API" \
  --query 'id' \
  --output text)

echo "API ID: $API_ID"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[0].id' \
  --output text)

# Create /api resource
API_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part api \
  --query 'id' \
  --output text)

# Create /api/readings resource
READINGS_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $API_RESOURCE \
  --path-part readings \
  --query 'id' \
  --output text)

# Create POST method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $READINGS_RESOURCE \
  --http-method POST \
  --authorization-type NONE

# Create Lambda integration
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $READINGS_RESOURCE \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:ACCOUNT_ID:function:water-monitor-sync-readings/invocations

# Deploy API
STAGE=$(aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --query 'id' \
  --output text)

echo "API Endpoint: https://$API_ID.execute-api.us-east-1.amazonaws.com/prod"
```

**Cost:** API Gateway free tier: 1M requests/month free, then $3.50 per million

---

### Step 4: AWS IoT Core (MQTT) Setup (Day 2 Afternoon)

#### 4.1 Create IoT Thing (Device)

```bash
# Create thing
aws iot create-thing \
  --thing-name Tank-1

# Create certificate
CERT=$(aws iot create-keys-and-certificate \
  --set-as-active \
  --certificate-pem-outfile device-cert.pem \
  --private-key-outfile device-private.key)

CERT_ARN=$(echo $CERT | jq -r '.certificateArn')
CERT_ID=$(echo $CERT | jq -r '.certificateId')

# Attach certificate to thing
aws iot attach-thing-principal \
  --thing-name Tank-1 \
  --principal $CERT_ARN

# Create policy
cat > iot-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:*",
      "Resource": "*"
    }
  ]
}
EOF

aws iot create-policy \
  --policy-name water-monitor-policy \
  --policy-document file://iot-policy.json

# Attach policy to certificate
aws iot attach-policy \
  --policy-name water-monitor-policy \
  --target $CERT_ARN
```

#### 4.2 Get IoT Endpoint

```bash
aws iot describe-endpoint \
  --endpoint-type iot:Data-ATS \
  --query 'endpointAddress'
```

**Store credentials:**
- `device-cert.pem` → Device firmware
- `device-private.key` → Device firmware
- Endpoint → Device config

**Topics:**
- `tank/Tank-1/reading/live` — Device publishes readings
- `tank/Tank-1/config/response` — Device publishes config
- `tank/Tank-1/config/request` — App requests config
- `tank/Tank-1/command` — App sends commands

---

## Part 3: Device Firmware Updates

### Step 5: Firmware Changes (Day 3)

#### 5.1 Update Device Configuration

**Edit `firmware/tank-sensor/src/config.h`:**

```cpp
// Cloud sync settings
#define CLOUD_SYNC_ENABLED 1
#define CLOUD_API_ENDPOINT "https://ACCOUNT_ID.execute-api.us-east-1.amazonaws.com/prod"
#define MQTT_BROKER "ax2xxxxxx.iot.us-east-1.amazonaws.com"
#define MQTT_PORT 8883

// Queue settings
#define QUEUE_MAX_CAPACITY 5000
#define QUEUE_BATCH_SIZE 100
#define QUEUE_SYNC_INTERVAL_MS 30000  // Sync every 30 seconds
```

#### 5.2 Implement API Sync Function

**Add to `firmware/tank-sensor/src/api_server.cpp`:**

```cpp
// Function to batch sync queue to cloud
bool ApiServer::syncQueueToCloud() {
    if (queueStore.pendingCount() == 0) {
        return true;  // Nothing to sync
    }
    
    // Build JSON array of readings
    StaticJsonDocument<4096> doc;
    JsonArray readings = doc.createNestedArray("readings");
    
    // Read up to QUEUE_BATCH_SIZE items
    for (int i = 0; i < QUEUE_BATCH_SIZE && i < queueStore.pendingCount(); i++) {
        QueueEntry entry = queueStore.readEntry(i);
        
        JsonObject reading = readings.createNestedObject();
        reading["device_id"] = config.d.node_id;
        reading["timestamp"] = entry.ts;
        reading["distance_cm"] = entry.distance_cm;
        reading["level_pct"] = entry.level_pct;
        reading["sensor_ok"] = entry.sensor_ok;
    }
    
    // Send to cloud
    HTTPClient http;
    http.begin(CLOUD_API_ENDPOINT "/api/readings");
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-App-ID", config.d.node_id);
    
    String payload;
    serializeJson(doc, payload);
    
    int httpCode = http.POST(payload);
    
    if (httpCode == 200) {
        // Parse response
        String response = http.getString();
        StaticJsonDocument<256> responseDoc;
        deserializeJson(responseDoc, response);
        
        int syncedCount = responseDoc["synced_count"] | 0;
        
        // Clear synced items from queue
        queueStore.clearSynced(syncedCount);
        
        Serial.printf("[Sync] Synced %d readings to cloud\n", syncedCount);
        return true;
    } else {
        Serial.printf("[Sync] Cloud sync failed: HTTP %d\n", httpCode);
        return false;
    }
}
```

#### 5.3 Add MQTT Publishing

**Add to `firmware/tank-sensor/src/main.cpp`:**

```cpp
// In commsTask, after WiFi connected:
if (mqttClient.connect(config.d.node_id)) {
    // Publish live reading
    char topic[64];
    snprintf(topic, sizeof(topic), "tank/%s/reading/live", config.d.node_id);
    
    char payload[256];
    snprintf(payload, sizeof(payload),
             "{\"timestamp\":%lu,\"distance_cm\":%.1f,\"level_pct\":%u,\"sensor_ok\":%s}",
             snap.last_read_ts, snap.distance_cm, snap.level_pct,
             snap.sensor_ok ? "true" : "false");
    
    mqttClient.publish(topic, payload);
    
    // Also sync queue periodically
    if (millis() - lastQueueSync > QUEUE_SYNC_INTERVAL_MS) {
        apiServer.syncQueueToCloud();
        lastQueueSync = millis();
    }
}
```

---

## Part 4: iOS App Updates

### Step 6: App Queue Layer (Day 4)

#### 6.1 Create SyncQueue Model

**Create `ios-app/mobile/WaterMonitor/Models/SyncQueueItem.swift`:**

```swift
import Foundation
import SwiftData

@Model final class SyncQueueItem {
    var id: UUID = UUID()
    var deviceID: String
    var readings: [DeviceReadingDTO] = []
    var status: String = "pending"  // pending, synced, failed
    var attempts: Int = 0
    var lastAttemptAt: Date?
    var syncedAt: Date?
    var createdAt: Date = Date()
    
    init(deviceID: String, readings: [DeviceReadingDTO]) {
        self.deviceID = deviceID
        self.readings = readings
    }
}

struct DeviceReadingDTO: Codable {
    var deviceID: String
    var timestamp: Int
    var distanceCM: Double
    var levelPct: Int
    var sensorOk: Bool
    var isTest: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case timestamp
        case distanceCM = "distance_cm"
        case levelPct = "level_pct"
        case sensorOk = "sensor_ok"
        case isTest = "is_test"
    }
}
```

#### 6.2 Update ConnectionManager for Cloud Sync

**Edit `ios-app/mobile/WaterMonitor/Services/ConnectionManager.swift`:**

```swift
// Add to ConnectionManager
@Observable
final class ConnectionManager {
    // ... existing code ...
    
    var isCloudOnline: Bool = false
    var syncQueueManager: SyncQueueManager?
    
    func setupCloudSync(modelContext: ModelContext) {
        syncQueueManager = SyncQueueManager(modelContext: modelContext)
        
        // Monitor cloud connectivity
        let monitor = NWPathMonitor()
        monitor.start(queue: DispatchQueue.global())
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isCloudOnline = path.status == .satisfied
                
                // Trigger sync if cloud came back online
                if self?.isCloudOnline == true {
                    self?.syncQueueManager?.syncPendingReadings()
                }
            }
        }
    }
    
    // When new reading arrives
    func saveReadingAndSync(_ status: DeviceStatus) {
        dataCache?.save(status)
        
        // If cloud online, push to cloud
        if isCloudOnline {
            // In background
            Task {
                await syncQueueManager?.pushReadingToCloud(status)
            }
        } else {
            // Queue locally
            syncQueueManager?.queueReading(status, deviceID: config?.nodeID ?? "")
        }
    }
}
```

#### 6.3 Create SyncQueueManager

**Create `ios-app/mobile/WaterMonitor/Services/SyncQueueManager.swift`:**

```swift
import Foundation
import SwiftData

actor SyncQueueManager {
    private let modelContext: ModelContext
    private var syncInProgress = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Queue reading locally when offline
    func queueReading(_ status: DeviceStatus, deviceID: String) {
        let dto = DeviceReadingDTO(
            deviceID: deviceID,
            timestamp: Int(Date().timeIntervalSince1970),
            distanceCM: status.distanceCM,
            levelPct: status.levelPct,
            sensorOk: status.sensorOk
        )
        
        let item = SyncQueueItem(deviceID: deviceID, readings: [dto])
        modelContext.insert(item)
        
        do {
            try modelContext.save()
        } catch {
            print("[SyncQueue] Error saving: \(error)")
        }
    }
    
    // Sync pending queue to cloud
    func syncPendingReadings() async {
        guard !syncInProgress else { return }
        syncInProgress = true
        defer { syncInProgress = false }
        
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate { $0.status == "pending" }
        )
        
        guard let items = try? modelContext.fetch(descriptor) else {
            return
        }
        
        for item in items {
            await syncItem(item)
        }
    }
    
    // Push single reading to cloud (when online)
    func pushReadingToCloud(_ status: DeviceStatus) async {
        let dto = DeviceReadingDTO(
            deviceID: status.deviceID,
            timestamp: Int(Date().timeIntervalSince1970),
            distanceCM: status.distanceCM,
            levelPct: status.levelPct,
            sensorOk: status.sensorOk
        )
        
        await syncItem(SyncQueueItem(deviceID: status.deviceID, readings: [dto]))
    }
    
    private func syncItem(_ item: SyncQueueItem) async {
        var url = URLComponents(string: "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/api/readings")!
        
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert DTOs to JSON
        let jsonData = try! JSONEncoder().encode(item.readings)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                item.attempts += 1
                item.lastAttemptAt = Date()
                // Retry later
                return
            }
            
            item.status = "synced"
            item.syncedAt = Date()
            try modelContext.save()
            
        } catch {
            item.attempts += 1
            item.lastAttemptAt = Date()
            print("[SyncQueue] Sync error: \(error)")
        }
    }
}
```

---

## Part 5: Integration & Testing

### Step 7: Testing Checklist

**Before production:**
- [ ] Test DynamoDB deduplication (send same reading twice, verify only one stored)
- [ ] Test RDS connections (check sync_queue table receives items)
- [ ] Test API Gateway (curl POST to /api/readings)
- [ ] Test Lambda cold start (acceptable latency?)
- [ ] Test MQTT connection from device
- [ ] Test app queue when WiFi off (readings queue, then sync on WiFi)
- [ ] Test multi-app sync (App A reads, App B sees reading)
- [ ] Test reading retention (old readings have TTL)

**AWS monitoring:**
```bash
# Monitor DynamoDB writes
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=water-monitor-readings \
  --start-time 2026-05-29T00:00:00Z \
  --end-time 2026-05-30T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Monitor Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=water-monitor-sync-readings \
  --start-time 2026-05-29T00:00:00Z \
  --end-time 2026-05-30T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

---

## Summary: Phase 2A Deliverables

| Component | Status | Files |
|-----------|--------|-------|
| **DynamoDB** | ✅ Readings table | schema |
| **RDS PostgreSQL** | ✅ All 6 tables | schema.sql |
| **API Gateway** | ✅ POST /api/readings | Lambda function |
| **Lambda** | ✅ Sync + dedup logic | lambda_sync_readings.py |
| **AWS IoT** | ✅ MQTT broker setup | certificates + policy |
| **Device Firmware** | ⏳ Queue sync + MQTT | api_server.cpp + main.cpp |
| **iOS App** | ⏳ SyncQueueManager | SyncQueueManager.swift |

---

## Cost Estimate (Monthly)

```
DynamoDB:         $1-5    (on-demand, reads/writes)
RDS micro:        $10-15  (free tier or micro instance)
API Gateway:      $3-5    (1M requests)
Lambda:           $5-10   (execution time)
AWS IoT:          $5-10   (messages published)
────────────────────────────
Total:            $25-45/month

(Significantly cheaper than Firebase or AWS at scale)
```

---

## Next: Execution Steps

**Week 1:**
1. Create DynamoDB + RDS (Days 1-2)
2. Deploy API Gateway + Lambda (Days 2-3)
3. Setup AWS IoT (Days 3-4)

**Week 2:**
4. Firmware updates (Days 5-6)
5. iOS app queue layer (Days 6-7)

**Week 3:**
6. Integration testing (Days 8-10)
7. Bug fixes + optimization

**Week 4:**
8. Production deployment
9. Monitoring setup
10. Documentation

