import os
import sys
import json
from sqlalchemy import create_engine, text

def main():
    print("🚀 Starting migration from local SQLite to Supabase...")
    local_url = "sqlite:///./pubo.db"
    supabase_url = 'postgresql://postgres.tixmkecbyeeehajlxpbo:fucbu9-xiwnus-giKmem@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres'
    
    local_engine = create_engine(local_url)
    supabase_engine = create_engine(supabase_url)
    
    trip_id = "513e3bb4-f48f-48ed-8aa5-7d093105230c"
    
    with local_engine.connect() as local_conn:
        trip_res = local_conn.execute(text(f"SELECT * FROM trips WHERE id='{trip_id}'"))
        trip_row = trip_res.fetchone()
        
        if not trip_row:
            print(f"❌ Trip {trip_id} not found locally.")
            return
            
        days_res = local_conn.execute(text(f"SELECT * FROM itinerary_days WHERE trip_id='{trip_id}'"))
        days_rows = days_res.fetchall()
        
        day_ids = [str(r[0]) for r in days_rows]
        spots_rows = []
        if day_ids:
            spots_res = local_conn.execute(text(f"SELECT * FROM itinerary_spots WHERE day_id IN ({','.join(day_ids)})"))
            spots_rows = spots_res.fetchall()
            
    print(f"📦 Found trip '{trip_row[1]}' with {len(days_rows)} days and {len(spots_rows)} spots locally.")
            
    with supabase_engine.connect() as remote_conn:
        # Check if trip already exists, if so delete it to replace
        remote_conn.execute(text(f"DELETE FROM trips WHERE id='{trip_id}'"))
        remote_conn.commit()
        print("🗑️ Cleared existing trip from Supabase.")
        
        # Insert trip
        trip_dict = dict(trip_row._mapping)
        remote_conn.execute(text("INSERT INTO trips (id, title, destination, start_date, end_date, cover_image_url, transport_mode, created_at, updated_at) VALUES (:id, :title, :destination, :start_date, :end_date, :cover_image_url, :transport_mode, :created_at, :updated_at)"), [trip_dict])
        print("✅ Migrated trip.")
        
        # Insert days (generate new IDs, keep a mapping to update spots)
        day_id_mapping = {}
        for day in days_rows:
            day_dict = dict(day._mapping)
            old_day_id = day_dict.pop('id') # remove id so it auto increments
            res = remote_conn.execute(text("INSERT INTO itinerary_days (trip_id, day_order, date, weekday, title) VALUES (:trip_id, :day_order, :date, :weekday, :title) RETURNING id"), [day_dict])
            new_day_id = res.scalar()
            day_id_mapping[old_day_id] = new_day_id
        print(f"✅ Migrated {len(days_rows)} days.")
            
        # Insert spots
        spots_to_insert = []
        for spot in spots_rows:
            spot_dict = dict(spot._mapping)
            spot_dict['day_id'] = day_id_mapping[spot_dict['day_id']]
            spot_dict['place_id'] = None # Avoid foreign key violation
            # Ensure JSON field notes is dumped if it's a list
            if isinstance(spot_dict['notes'], list):
                spot_dict['notes'] = json.dumps(spot_dict['notes'])
            spots_to_insert.append(spot_dict)
            
        if spots_to_insert:
            remote_conn.execute(text("INSERT INTO itinerary_spots (id, day_id, place_id, name, category, start_time, stay_duration, notes, image_url, latitude, longitude, sort_order, travel_time, travel_distance, travel_mode) VALUES (:id, :day_id, :place_id, :name, :category, :start_time, :stay_duration, :notes, :image_url, :latitude, :longitude, :sort_order, :travel_time, :travel_distance, :travel_mode)"), spots_to_insert)
        print(f"✅ Migrated {len(spots_rows)} spots.")
        
        remote_conn.commit()
        print("🎉 Migration complete!")

if __name__ == "__main__":
    main()
