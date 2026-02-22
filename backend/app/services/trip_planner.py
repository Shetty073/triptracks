import json
from app.services.cache import cache_service
from typing import List, Dict
import math
from app.models.trip import Location, Leg

# Try importing and initializing geomaps_sdk
try:
    from geomaps_sdk.maps_sdk import LocationClient, GeoapifyProvider, GeoPoint
    from app.core.config import settings
    if settings.GEOMAPS_API_KEY:
        provider = GeoapifyProvider(api_key=settings.GEOMAPS_API_KEY)
        maps_client = LocationClient(provider=provider)
    else:
        maps_client = None
except (ImportError, Exception):
    maps_client = None


class TripPlannerService:
    @staticmethod
    def _haversine(lat1, lon1, lat2, lon2):
        R = 6371  # radius of Earth in km
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        a = math.sin(delta_phi / 2.0) ** 2 + \
            math.cos(phi1) * math.cos(phi2) * \
            math.sin(delta_lambda / 2.0) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    @staticmethod
    def get_autocomplete(query: str) -> List[Dict]:
        cache_key = f"autocomplete_{query.replace(' ', '_')}"
        cached = cache_service.get(cache_key)
        if cached is not None:
            return cached

        results = []
        if maps_client:
            try:
                api_results = maps_client.autocomplete(query, limit=5)
                for res in api_results:
                    results.append({
                        "name": res.formatted_address or res.address.city or "Unknown",
                        "lat": res.location.latitude,
                        "lng": res.location.longitude
                    })
            except Exception as e:
                print(f"Geomaps SDK error: {e}")

        # If no client or error, return dummy data to keep app working
        if not results:
            results = [
                {"name": f"{query} City", "lat": 40.7128, "lng": -74.0060},
                {"name": f"{query} Town", "lat": 34.0522, "lng": -118.2437}
            ]

        cache_service.set(cache_key, results, ttl=3600)  # cache for 1 hour
        return results

    @staticmethod
    def calculate_leg(src: Location, dest: Location) -> Leg:
        cache_key = f"route_{src.lat}_{src.lng}_{dest.lat}_{dest.lng}"
        cached = cache_service.get(cache_key)
        if cached is not None:
            return Leg(**cached)

        leg = None
        if maps_client:
            try:
                src_pt = GeoPoint(latitude=src.lat, longitude=src.lng)
                dest_pt = GeoPoint(latitude=dest.lat, longitude=dest.lng)
                route = maps_client.route(src_pt, dest_pt)
                leg = Leg(distance_km=route.distance_km, estimated_time_mins=int(route.duration_minutes))
            except Exception as e:
                print(f"Geomaps Route Error: {e}")

        if not leg:
            # Fallback to haversine distance and assume 60km/h avg speed
            dist_km = TripPlannerService._haversine(src.lat, src.lng, dest.lat, dest.lng)
            leg = Leg(distance_km=round(dist_km, 2), estimated_time_mins=int((dist_km / 60) * 60))

        cache_service.set(cache_key, leg.dict(), ttl=3600)  # cache for 1 hour
        return leg

    @staticmethod
    def calculate_trip_itinerary(source: Location, destination: Location, stops: List[Location], avg_daily_dist: float) -> Dict:
        points = [source] + stops + [destination]
        legs = []
        total_dist = 0.0
        total_time = 0

        for i in range(len(points) - 1):
            leg = TripPlannerService.calculate_leg(points[i], points[i + 1])
            legs.append(leg)
            total_dist += leg.distance_km
            total_time += leg.estimated_time_mins

        # Calculate days needed based on avg daily driving distance
        days_needed = math.ceil(total_dist / avg_daily_dist) if avg_daily_dist > 0 else 1

        # Suggest additional stops for segments longer than daily limit
        suggested_stops = []
        for i, leg in enumerate(legs):
            if leg.distance_km > avg_daily_dist:
                suggested_stops.append({
                    "segment": f"between {points[i].name} and {points[i + 1].name}",
                    "distance": leg.distance_km,
                    "reason": "Exceeds your comfortable daily driving limit"
                })

        return {
            "legs": legs,
            "total_distance_km": round(total_dist, 2),
            "total_estimated_time_mins": total_time,
            "estimated_days": days_needed,
            "suggestions": suggested_stops
        }
