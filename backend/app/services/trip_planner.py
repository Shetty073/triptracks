import json
import math
from typing import List, Dict

from app.services.cache import cache_service
from app.models.trip import Location, Leg


def _get_maps_client():
    """Lazily initialise the GeoMaps client so settings are fully loaded from .env first."""
    try:
        from geomaps_sdk.maps_sdk import LocationClient, GeoapifyProvider
        from app.core.config import settings
        if not settings.GEOMAPS_API_KEY:
            return None
        provider = GeoapifyProvider(api_key=settings.GEOMAPS_API_KEY)
        return LocationClient(provider=provider)
    except Exception as e:
        print(f"GeoMaps SDK init error: {e}")
        return None


class TripPlannerService:
    @staticmethod
    def _haversine(lat1, lon1, lat2, lon2):
        R = 6371  # km
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    @staticmethod
    def get_autocomplete(query: str) -> List[Dict]:
        cache_key = f"autocomplete_{query.replace(' ', '_')}"
        cached = cache_service.get(cache_key)
        if cached is not None:
            return cached

        results = []
        maps_client = _get_maps_client()
        if maps_client:
            try:
                api_results = maps_client.autocomplete(query, limit=5)
                for res in api_results:
                    results.append({
                        "name": res.address.formatted_address or res.address.city or query,
                        "lat": res.location.latitude,
                        "lng": res.location.longitude,
                    })
            except Exception as e:
                print(f"GeoMaps autocomplete error: {e}")

        # Fallback: deterministic hash-derived coords so different cities differ
        if not results:
            h = sum(ord(c) * (i + 1) for i, c in enumerate(query.lower()))
            lat  = -60.0 + (h % 1200) / 10.0
            lng  = -170.0 + (h % 3400) / 10.0
            lat2 = -60.0 + ((h + 137) % 1200) / 10.0
            lng2 = -170.0 + ((h + 137) % 3400) / 10.0
            results = [
                {"name": f"{query} City", "lat": round(lat, 4),  "lng": round(lng, 4)},
                {"name": f"{query} Town", "lat": round(lat2, 4), "lng": round(lng2, 4)},
            ]

        cache_service.set(cache_key, results, ttl=3600)
        return results

    @staticmethod
    def calculate_leg(src: Location, dest: Location) -> Leg:
        cache_key = f"route_{src.lat}_{src.lng}_{dest.lat}_{dest.lng}"
        cached = cache_service.get(cache_key)
        if cached is not None:
            return Leg(**cached)

        leg = None
        maps_client = _get_maps_client()
        if maps_client:
            try:
                from geomaps_sdk.maps_sdk import GeoPoint
                src_pt  = GeoPoint(latitude=src.lat,  longitude=src.lng)
                dest_pt = GeoPoint(latitude=dest.lat, longitude=dest.lng)
                route = maps_client.route(src_pt, dest_pt)
                leg = Leg(
                    distance_km=round(float(route.distance_km), 2),
                    estimated_time_mins=int(route.duration_minutes),
                )
            except Exception as e:
                print(f"GeoMaps route error: {e}")

        if not leg:
            dist_km = TripPlannerService._haversine(src.lat, src.lng, dest.lat, dest.lng)
            leg = Leg(
                distance_km=round(dist_km, 2),
                estimated_time_mins=int((dist_km / 60) * 60),
            )

        cache_service.set(cache_key, leg.dict(), ttl=3600)
        return leg

    @staticmethod
    def calculate_trip_itinerary(
        source: Location,
        destination: Location,
        stops: List[Location],
        avg_daily_dist: float,
    ) -> Dict:
        points = [source] + stops + [destination]
        legs = []
        total_dist = 0.0
        total_time = 0

        for i in range(len(points) - 1):
            leg = TripPlannerService.calculate_leg(points[i], points[i + 1])
            legs.append(leg)
            total_dist += leg.distance_km
            total_time += leg.estimated_time_mins

        days_needed = math.ceil(total_dist / avg_daily_dist) if avg_daily_dist > 0 else 1

        suggested_stops = []
        for i, leg in enumerate(legs):
            if avg_daily_dist > 0 and leg.distance_km > avg_daily_dist:
                suggested_stops.append({
                    "segment": f"between {points[i].name} and {points[i + 1].name}",
                    "distance": leg.distance_km,
                    "reason": "Exceeds your comfortable daily driving limit",
                })

        return {
            "legs": legs,
            "total_distance_km": round(total_dist, 2),
            "total_estimated_time_mins": total_time,
            "estimated_days": days_needed,
            "suggestions": suggested_stops,
        }
