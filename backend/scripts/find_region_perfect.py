import socket
import psycopg2
import sys

regions = [
    'ap-northeast-1', 'ap-northeast-2', 'ap-northeast-3', 'ap-east-1',
    'ap-south-1', 'ap-southeast-1', 'ap-southeast-2',
    'ca-central-1',
    'eu-central-1', 'eu-west-1', 'eu-west-2', 'eu-west-3', 'eu-north-1',
    'sa-east-1',
    'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'
]

found = False
for region in regions:
    host = f"aws-0-{region}.pooler.supabase.com"
    print(f"Testing {host}...", end=" ")
    sys.stdout.flush()
    try:
        conn = psycopg2.connect(
            host=host,
            user="postgres.tixmkecbyeeehajlxpbo",
            password="fucbu9-xiwnus-giKmem",
            database="postgres",
            port=6543,
            connect_timeout=2
        )
        print("SUCCESS (Fully connected)")
        conn.close()
        found = True
        break
    except Exception as e:
        err = str(e).strip()
        if "password authentication failed" in err:
            print("FOUND (but password wrong)")
            found = True
            break
        elif "tenant or user not found" in err.lower() or "tenant/user" in err.lower():
            print("Not here (Tenant not found)")
        elif "nodename nor servname" in err.lower():
            print("Not here (DNS NXDOMAIN)")
        elif "timeout" in err.lower():
            print("Timeout")
        else:
            print(f"Error ({err})")

if not found:
    print("Could not find in AWS regions. Testing generic pooler...")
    try:
        conn = psycopg2.connect(
            host="tixmkecbyeeehajlxpbo.pooler.supabase.com",
            user="postgres.tixmkecbyeeehajlxpbo",
            password="fucbu9-xiwnus-giKmem",
            database="postgres",
            port=6543,
            connect_timeout=2
        )
        print("SUCCESS generic")
    except Exception as e:
        print(f"Generic pooler failed: {e}")
