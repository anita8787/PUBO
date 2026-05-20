import socket
import psycopg2

regions = [
    'ap-northeast-1', 'ap-northeast-2', 'ap-northeast-3',
    'ap-south-1', 'ap-southeast-1', 'ap-southeast-2',
    'ca-central-1',
    'eu-central-1', 'eu-west-1', 'eu-west-2', 'eu-west-3', 'eu-north-1',
    'sa-east-1',
    'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'
]

found = False
for region in regions:
    host = f"aws-0-{region}.pooler.supabase.com"
    try:
        # We only wait 1.5 seconds per connection because if it's the wrong region, 
        # the Supavisor returns a FATAL error almost immediately.
        # If it's the right region it will successfully auth or give a password error.
        conn = psycopg2.connect(
            host=host,
            user="postgres.tixmkecbyeeehajlxpbo",
            password="fucbu9-xiwnus-giKmem",
            database="postgres",
            port=6543,
            connect_timeout=2
        )
        print(f"SUCCESS: {host}")
        conn.close()
        found = True
        break
    except Exception as e:
        err_msg = str(e)
        if "password authentication failed" in err_msg:
            # If we hit a password error, the tenant WAS found! Region is correct!
            print(f"FOUND TENANT (Password Error): {host}")
            found = True
            break
        elif "tenant/user" not in err_msg.lower() and "tenant or user" not in err_msg.lower():
            # Let's see what other errors occur
            print(f"Failed {host} with unexpected error: {err_msg.strip()}")

if not found:
    print("Could not locate the correct region pooler.")
