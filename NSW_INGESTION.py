"""
NSW Fuel API extractor — calls all six endpoints and writes files.

Fill in API_KEY / API_SECRET below, then:  python nsw_fuel_extract.py
Requires:  pip install requests

NOTE: hardcoded secrets are fine for a local one-off, but do NOT commit real
credentials to git. Swap to environment variables before pushing.
"""

import base64
import csv
import datetime as dt
import json
import os
import time
import uuid

import requests

# ----------------------------------------------------------------- CONFIG 
API_KEY    = "##################"
API_SECRET = "##################"

BASE   = "https://api.onegov.nsw.gov.au"
OUTDIR = "nsw_fuel_output"

# Sample parameters for the parameterised endpoints (change as needed)
FUELTYPE     = "E10"
STATION_CODE = "112"                 # example NSW station code
LATITUDE     = "-33.8688"            # Sydney CBD
LONGITUDE    = "151.2093"
RADIUS       = "5"                   # km
NAMED_LOC    = "2000"               # postcode / suburb for /location


# ----------------------------------------------------------------- auth + helpers
def get_access_token():
    """OAuth2 client-credentials: Basic base64(key:secret) -> bearer token (~12h)."""
    auth = base64.b64encode(f"{API_KEY}:{API_SECRET}".encode()).decode()
    r = requests.get(
        f"{BASE}/oauth/client_credential/accesstoken",
        params={"grant_type": "client_credentials"},
        headers={"Authorization": f"Basic {auth}"},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()["access_token"]


def build_headers(token):
    """Every data call needs these headers; transactionid + timestamp are per-call."""
    return {
        "Authorization":     f"Bearer {token}",
        "apikey":            API_KEY,
        "Content-Type":      "application/json; charset=utf-8",
        "transactionid":     str(uuid.uuid4()),
        "requesttimestamp":  dt.datetime.utcnow().strftime("%d/%m/%Y %I:%M:%S %p"),  # UTC, 12h AM/PM
        "if-modified-since": "01/01/2020 12:00:00 AM",                               # old -> full pull
    }


def call(method, path, token, body=None, retries=3):
    """GET/POST with fresh headers + small retry on transient failures."""
    url = f"{BASE}{path}"
    for attempt in range(1, retries + 1):
        try:
            r = requests.request(
                method, url, headers=build_headers(token),
                json=body, timeout=60,
            )
            r.raise_for_status()
            return r.json()
        except requests.RequestException as e:
            if attempt == retries:
                print(f"  ! {method} {path} failed after {retries} tries: {e}")
                return None
            time.sleep(2 ** attempt)


def save_json(name, data):
    path = os.path.join(OUTDIR, name)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  -> {path}")


# ----------------------------------------------------------------- endpoint calls
def get_reference_data(token):
    """GET /FuelCheckRefData/v1/fuel/lovs — dimensions (stations, brands, fuel types)."""
    data = call("GET", "/FuelCheckRefData/v1/fuel/lovs", token)
    if not data:
        return
    save_json("lovs_raw.json", data)

    # flatten stations -> station dimension source
    stations = data.get("stations", {}).get("items", [])
    with open(os.path.join(OUTDIR, "stations.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["stationid", "code", "brand", "brandid", "name", "address", "latitude", "longitude"])
        for s in stations:
            loc = s.get("location") or {}
            w.writerow([s.get("stationid"), s.get("code"), s.get("brand"), s.get("brandid"),
                        s.get("name"), s.get("address"), loc.get("latitude"), loc.get("longitude")])
    print(f"  -> stations.csv ({len(stations)} rows)")


def get_all_prices(token):
    """GET /FuelPriceCheck/v1/fuel/prices — all current prices (FACT source)."""
    data = call("GET", "/FuelPriceCheck/v1/fuel/prices", token)
    if not data:
        return
    save_json("prices_all_raw.json", data)

    prices = data.get("prices", [])

    
    with open(os.path.join(OUTDIR, "prices.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["stationcode", "fueltype", "price", "lastupdated"])
        for p in prices:
            w.writerow([p.get("stationcode"), p.get("fueltype"), p.get("price"), p.get("lastupdated")])
    print(f"  -> prices.csv ({len(prices)} rows)")


def get_new_prices(token):
    """GET /FuelPriceCheck/v1/fuel/prices/new — delta since last call (INCREMENTAL).
    Caveat: watermark is server-side and resets daily; a crash loses the delta."""
    data = call("GET", "/FuelPriceCheck/v1/fuel/prices/new", token)
    if data:
        save_json("prices_new_raw.json", data)


def get_prices_for_station(token, station_code):
    """GET /FuelPriceCheck/v1/fuel/prices/station/{code}."""
    data = call("GET", f"/FuelPriceCheck/v1/fuel/prices/station/{station_code}", token)
    if data:
        save_json(f"prices_station_{station_code}_raw.json", data)


def get_prices_nearby(token):
    """POST /FuelPriceCheck/v1/fuel/prices/nearby — within radius of a point."""
    body = {
        "fueltype": FUELTYPE,
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "radius": RADIUS,
        "sortby": "price",
        "sortascending": "true",
    }
    data = call("POST", "/FuelPriceCheck/v1/fuel/prices/nearby", token, body=body)
    if data:
        save_json("prices_nearby_raw.json", data)


def get_prices_for_location(token):
    """POST /FuelPriceCheck/v1/fuel/prices/location — single fuel type + named location.
    Body field names follow the API's Postman collection; adjust if the sandbox differs."""
    body = {
        "fueltype": FUELTYPE,
        "namedlocationid": NAMED_LOC,
        "sortby": "price",
        "sortascending": "true",
    }
    data = call("POST", "/FuelPriceCheck/v1/fuel/prices/location", token, body=body)
    if data:
        save_json("prices_location_raw.json", data)


# ----------------------------------------------------------------- main
def main():
    os.makedirs(OUTDIR, exist_ok=True)
    print("Authenticating...")
    token = get_access_token()
    print("Token acquired.\nCalling endpoints:")

    get_reference_data(token)           # -> lovs_raw.json + stations.csv   (dimensions)
    get_all_prices(token)               # -> prices_all_raw.json + prices.csv (fact)
    get_new_prices(token)               # -> prices_new_raw.json            (incremental)
    get_prices_for_station(token, STATION_CODE)
    get_prices_nearby(token)
    get_prices_for_location(token)

    print(f"\nDone. Files in ./{OUTDIR}/")
    print("Load into Snowflake Bronze: stations.csv -> stations_raw, prices.csv -> prices_raw")


if __name__ == "__main__":
    main()