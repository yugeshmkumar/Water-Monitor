# Phase 2A Implementation Guide — AWS Cloud Sync (SQS-First Architecture)

**Duration:** 3-4 weeks  
**AWS Services:** SQS, DynamoDB, RDS, Lambda, CloudWatch, IAM, Cognito  
**Architecture Pattern:** Follows AWS IoT, Google Cloud, Azure, and industry standards  
**Team:** 1 backend engineer + device firmware updates + iOS app updates

---

## Why Option 2 (SQS-First)?

This architecture matches patterns from:
- **AWS IoT Core** (official AWS recommendation for devices)
- **Google Cloud IoT** (Pub/Sub → Cloud Functions)
- **Azure IoT Hub** (topics → Stream Analytics)
- **Apache Kafka** (producer → topic → consumer)

**Key principle:** Durable queue sits between producer (mobile app) and consumer (Lambda), ensuring zero data loss and independent scaling.

---

## Part 1: AWS Architecture

### 1.1 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                  Device (ESP32)                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ NVS Queue (2000 readings)                            │    │
│  │ Syncs every 30s to app via BLE/WiFi                 │    │
│  └──────────────────────────────────────────────────────┘    │
└────────────────┬─────────────────────────────────────────────┘
                 │ (BLE/WiFi sync)
                 ▼
┌──────────────────────────────────────────────────────────────┐
│              Mobile App (iOS)                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ SwiftData SyncQueue                                  │    │
│  │ ├─ Device readings (pending/synced)                 │    │
│  │ ├─ Device queue flush entries                       │    │
│  │ └─ Status: pending → synced → cleared               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  while offline: queue builds up                             │
│  when online: batch push to SQS (AWS SDK)                   │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ AWS SDK (SigV4 signed)
                 │ SendMessageBatch to SQS
                 ▼
┌──────────────────────────────────────────────────────────────┐
│                      AWS Account                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  SQS Queue: water-monitor-readings                   │   │
│  │  ├─ Retention: 14 days (automatic replay)           │   │
│  │  ├─ Visibility timeout: 30 seconds                  │   │
│  │  ├─ DLQ: water-monitor-readings-dlq                 │   │
│  │  └─ Messages are durable (won't lose)               │   │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │                                            │
│        ┌────────┴─────────────────────┐                     │
│        │  Lambda polls SQS every 1min  │                    │
│        │  (batch 10 messages at once)  │                    │
│        ▼                               ▼                    │
│  ┌────────────────────────────────────────┐                │
│  │  Lambda: SyncReadings                  │                │
│  │  ├─ For each message:                  │                │
│  │  │  ├─ Parse JSON                      │                │
│  │  │  ├─ Dedup check (DynamoDB)         │                │
│  │  │  ├─ Validate data                   │                │
│  │  │  ├─ Write to DynamoDB              │                │
│  │  │  └─ Write to RDS                   │                │
│  │  ├─ Publish anomalies to SNS          │                │
│  │  └─ Delete from SQS on success        │                │
│  └────────────┬─────────────────────────┘                │
│               │                                           │
│      ┌────────┴──────────────┬─────────────┐             │
│      ▼                       ▼             ▼             │
│  ┌─────────┐           ┌──────────┐   ┌──────┐          │
│  │DynamoDB │           │RDS       │   │ SNS  │          │
│  │Readings │           │PostgreSQL│   │Alerts│          │
│  └─────────┘           └──────────┘   └──────┘          │
│  (time-series)         (metadata)     (notify)          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [PHASE 2B] API Gateway (for reads)              │  │
│  │  ├─ GET /api/readings?device=Tank-1             │  │
│  │  ├─ GET /api/insights/{device_id}               │  │
│  │  └─ Auth: API Key + Cognito                      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [PHASE 2C] AWS IoT Core (device commands)       │  │
│  │  ├─ MQTT: tank/{device_id}/config/request       │  │
│  │  ├─ MQTT: tank/{device_id}/command              │  │
│  │  └─ Lambda → Device via MQTT                     │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow

```
Scenario 1: Mobile Online
───────────────────────────
1. Device reads sensor → syncs to app (BLE/WiFi)
2. App receives reading in SyncQueueManager
3. SyncQueue marked as "pending"
4. App batch: collect up to 100 readings
5. App invokes: SQS.SendMessageBatch() with AWS SDK
6. SQS receives and stores durably (14 days)
7. SQS returns success immediately
8. App marks queue items as "synced" (deletes from local SwiftData)
9. Lambda polls SQS every minute, processes batch
10. Lambda writes to DynamoDB + RDS
11. Lambda deletes message from SQS
12. Mobile app: All readings now in cloud ✓

Scenario 2: Mobile Offline
──────────────────────────
1. Device reads sensor → syncs to app (BLE/WiFi)
2. App receives reading in SyncQueueManager
3. SyncQueue marked as "pending"
4. App detects no internet (NWPathMonitor)
5. App queues reading locally in SwiftData (survives reboot)
6. App keeps accumulating (offline for 2 hours)
7. Mobile comes online
8. NWPathMonitor detects connectivity
9. App batches pending items from SwiftData
10. App invokes: SQS.SendMessageBatch()
11. SQS durably stores all (no loss)
12. App marks as "synced" in SwiftData
13. Lambda processes batch from SQS
14. All data now in cloud ✓

Scenario 3: Cloud Lambda Down / Network Drops
──────────────────────────────────────────────
1. App sends 100 readings to SQS
2. SQS stores durably
3. App marks locally as "synced" (can delete from SwiftData now)
4. Lambda crashes or network drops during processing
5. Message stays in SQS (never deleted)
6. After visibility timeout (30s), message reappears
7. Lambda retries automatically (no manual intervention)
8. On 3rd failure: message moves to DLQ (we can inspect)
9. Result: No data loss, Lambda can restart ✓
```

---

## Part 2: Step-by-Step Implementation

### Step 1: SQS Queue Setup (Day 1 Morning)

```bash
# Set variables
QUEUE_NAME="water-monitor-readings"
DLQ_NAME="water-monitor-readings-dlq"
REGION="us-east-1"

# Create DLQ first
DLQ_URL=$(aws sqs create-queue \
  --queue-name $DLQ_NAME \
  --region $REGION \
  --query 'QueueUrl' \
  --output text)

DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names QueueArn \
  --region $REGION \
  --query 'Attributes.QueueArn' \
  --output text)

echo "DLQ ARN: $DLQ_ARN"

# Create main queue with DLQ attached
QUEUE_URL=$(aws sqs create-queue \
  --queue-name $QUEUE_NAME \
  --attributes \
    MessageRetentionPeriod=1209600 \
    VisibilityTimeout=30 \
    RedrivePolicy="{\"deadLetterTargetArn\":\"$DLQ_ARN\",\"maxReceiveCount\":3}" \
  --region $REGION \
  --query 'QueueUrl' \
  --output text)

echo "Queue URL: $QUEUE_URL"

# Get Queue ARN for Lambda permissions
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names QueueArn \
  --region $REGION \
  --query 'Attributes.QueueArn' \
  --output text)

echo "Queue ARN: $QUEUE_ARN"
```

**SQS Configuration:**
- **Message retention:** 14 days (enough for offline scenario)
- **Visibility timeout:** 30 seconds (Lambda has 30s to process, if fails, message reappears)
- **Redrive policy:** 3 failures → message goes to DLQ (we can inspect what failed)

---

### Step 2: DynamoDB Setup (Day 1 Afternoon)

```bash
TABLE_NAME="water-monitor-readings"

# Create readings table
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=device_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=device_id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --ttl-specification AttributeName=expires_at,Enabled=true \
  --region $REGION

# Wait for table
aws dynamodb wait table-exists \
  --table-name $TABLE_NAME \
  --region $REGION

# Add GSI for date-range queries
aws dynamodb update-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=device_id,AttributeType=S \
    AttributeName=created_at,AttributeType=N \
  --global-secondary-indexes \
    IndexName=device_created_index,\
    Keys=[{AttributeName=device_id,KeyType=HASH},{AttributeName=created_at,KeyType=RANGE}],\
    Projection={ProjectionType=ALL},\
    ProvisionedThroughput={ReadCapacityUnits=100,WriteCapacityUnits=100} \
  --region $REGION
```

**DynamoDB Item Schema:**
```json
{
  "device_id": "Tank-1",
  "timestamp": 1717077600,
  "distance_cm": 35.2,
  "level_pct": 62,
  "sensor_ok": true,
  "created_at": 1717077603,
  "expires_at": 1748613600,
  "synced_from_app": "device-ios-1",
  "dedup_key": "Tank-1_1717077600"
}
```

---

### Step 3: RDS PostgreSQL (Day 2 Morning)

```bash
# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier water-monitor-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password 'YourSecurePassword123!' \
  --allocated-storage 20 \
  --backup-retention-period 7 \
  --enable-iam-database-authentication \
  --region $REGION

# Wait for instance
aws rds wait db-instance-available \
  --db-instance-identifier water-monitor-postgres \
  --region $REGION

# Get endpoint
ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier water-monitor-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $ENDPOINT"
```

**PostgreSQL Schema:**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  device_id VARCHAR UNIQUE NOT NULL,
  config JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE anomalies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR NOT NULL,
  type VARCHAR NOT NULL,
  severity VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR NOT NULL,
  period_date DATE NOT NULL,
  avg_level_pct FLOAT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

### Step 4: Lambda Function (Day 2 Afternoon)

**Save as `lambda_sync_readings.py`:**

```python
import json
import boto3
import os
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
rds_client = boto3.client('rds-data')
sns = boto3.client('sns')

TABLE_NAME = os.environ['DYNAMODB_TABLE']
ANOMALY_TOPIC = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    """
    Triggered by SQS messages (batch)
    event['Records'] = array of SQS messages
    """
    table = dynamodb.Table(TABLE_NAME)
    synced = []
    failed = []
    
    try:
        for record in event['Records']:
            try:
                # Parse SQS message
                body = json.loads(record['Body'])
                readings = body.get('readings', [])
                
                for reading in readings:
                    device_id = reading.get('device_id')
                    timestamp = reading.get('timestamp')
                    
                    # Dedup: check if already exists
                    response = table.get_item(
                        Key={
                            'device_id': device_id,
                            'timestamp': int(timestamp)
                        }
                    )
                    
                    if 'Item' in response:
                        # Already exists, skip
                        print(f"[Dedup] Skipping duplicate: {device_id} @ {timestamp}")
                        continue
                    
                    # Validate
                    if not (0 < reading.get('distance_cm', 0) < 600):
                        print(f"[Validate] Invalid distance: {reading.get('distance_cm')}")
                        continue
                    
                    # Write to DynamoDB
                    now = int(datetime.now().timestamp())
                    item = {
                        'device_id': device_id,
                        'timestamp': int(timestamp),
                        'distance_cm': float(reading.get('distance_cm')),
                        'level_pct': int(reading.get('level_pct')),
                        'sensor_ok': reading.get('sensor_ok', True),
                        'created_at': now,
                        'expires_at': now + (365 * 86400),  # 1 year
                        'dedup_key': f"{device_id}_{timestamp}"
                    }
                    
                    table.put_item(Item=item)
                    synced.append({
                        'device_id': device_id,
                        'timestamp': timestamp
                    })
                    
                    # Check for anomalies (stub for Phase 2B)
                    if reading.get('level_pct', 0) < 10:
                        sns.publish(
                            TopicArn=ANOMALY_TOPIC,
                            Subject=f'Low water level: {device_id}',
                            Message=f'Device {device_id} level at {reading.get("level_pct")}%'
                        )
                
                # Delete message from SQS (success)
                print(f"[Success] Processed {len(readings)} readings from SQS")
                
            except Exception as e:
                # If any error, message stays in SQS for retry
                # After 3 retries, goes to DLQ
                print(f"[Error] Processing message: {e}")
                failed.append(str(e))
                raise  # Let Lambda retry handle it
        
        return {
            'statusCode': 200,
            'body': {
                'synced_count': len(synced),
                'failed_count': len(failed)
            }
        }
        
    except Exception as e:
        print(f"[Fatal] Lambda error: {e}")
        raise  # Trigger retry + DLQ
```

**Deploy Lambda:**

```bash
# Package
cd /path/to/lambda
zip -r sync-readings.zip lambda_sync_readings.py

# Create role
ROLE_ARN=$(aws iam create-role \
  --role-name water-monitor-lambda-sync \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --region $REGION \
  --query 'Role.Arn' \
  --output text)

# Attach policies
aws iam attach-role-policy \
  --role-name water-monitor-lambda-sync \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam attach-role-policy \
  --role-name water-monitor-lambda-sync \
  --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

aws iam attach-role-policy \
  --role-name water-monitor-lambda-sync \
  --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess

# Create function
aws lambda create-function \
  --function-name water-monitor-sync-readings \
  --runtime python3.11 \
  --role $ROLE_ARN \
  --handler lambda_sync_readings.lambda_handler \
  --zip-file fileb://sync-readings.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables={DYNAMODB_TABLE=water-monitor-readings,SNS_TOPIC_ARN=arn:aws:sns:...} \
  --region $REGION

# Create event source mapping (SQS → Lambda)
aws lambda create-event-source-mapping \
  --event-source-arn $QUEUE_ARN \
  --function-name water-monitor-sync-readings \
  --enabled \
  --batch-size 10 \
  --region $REGION
```

---

## Part 3: iOS App Implementation

### Step 5: Update iOS App for SQS

**Create `ios-app/mobile/WaterMonitor/Services/SQSManager.swift`:**

```swift
import Foundation
import AWSSQS

actor SQSManager {
    private let sqs = AWSSQS.default()
    private let queueUrl = "https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/water-monitor-readings"
    
    func sendReadingsBatch(_ items: [DeviceReading]) async throws {
        guard !items.isEmpty else { return }
        
        var entries: [AWSSQSSendMessageBatchRequestEntry] = []
        
        for (index, item) in items.enumerated() {
            let entry = AWSSQSSendMessageBatchRequestEntry()
            entry.id = String(index)
            entry.messageBody = jsonSerialize(item)
            entries.append(entry)
        }
        
        let request = AWSSQSSendMessageBatchRequest()
        request.queueUrl = queueUrl
        request.entries = entries
        
        let response = try await sqs.sendMessageBatch(request).get()
        
        print("[SQS] Sent \(response.successful?.count ?? 0) messages")
        
        if let failed = response.failed, !failed.isEmpty {
            throw NSError(domain: "SQS", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Some messages failed"])
        }
    }
    
    private func jsonSerialize(_ item: DeviceReading) -> String {
        // Convert to JSON string
        let encoder = JSONEncoder()
        let data = try! encoder.encode(item)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
```

**Update `ConnectionManager.swift`:**

```swift
@Observable
final class ConnectionManager {
    let sqs = SQSManager()
    
    func syncQueueToCloud(items: [DeviceReading]) async {
        guard WiFi.isConnected else {
            print("[Sync] Offline, queuing locally")
            return
        }
        
        do {
            try await sqs.sendReadingsBatch(items)
            print("[Sync] Sent to SQS successfully")
            // Mark items as synced in SwiftData
        } catch {
            print("[Sync] Failed: \(error)")
            // Keep in local queue for retry
        }
    }
}
```

---

## Part 4: Cost Estimate

| Service | Monthly Cost |
|---------|----------|
| SQS (4.3M messages) | $2 |
| DynamoDB (on-demand) | $10 |
| RDS (micro) | $15 |
| Lambda (1M invocations) | $5 |
| SNS | $1 |
| **Total** | **$33/month** |

---

## Implementation Timeline

**Week 1:**
- Day 1: SQS queue + DLQ setup
- Day 2: DynamoDB + RDS tables
- Day 3: Lambda function + event source mapping

**Week 2:**
- Day 4-5: iOS app SQS integration
- Day 6: Device firmware updates (already have queue syncing)
- Day 7: Integration testing

**Week 3:**
- Days 8-10: Bug fixes, offline scenario testing, monitoring setup
- Day 11-14: Production deployment, documentation

---

## Next: Monitoring & Observability

(Phase 2B will add CloudWatch dashboards, alarms, X-Ray tracing)

