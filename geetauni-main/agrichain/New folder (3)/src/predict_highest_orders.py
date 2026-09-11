"""
Highest Orders & Regional Demand Surge Predictor
Uses the trained LightGBM Quantile ML Pipeline to evaluate all regional mandi
corridors and predict where the highest volume orders and best price realizations
will originate next.
"""

import sys
import io
import json
import argparse
from pathlib import Path
from datetime import datetime, timedelta

# Ensure UTF-8 output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Ensure project root is in sys.path
BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

try:
    from src.config import CORRIDOR_COORDINATES, COMMODITIES
    from src.inference import predict_demand_and_price
    HAS_ML_DEPS = True
except Exception as e:
    HAS_ML_DEPS = False
    CORRIDOR_COORDINATES = {
        ("Rice", "Karnal", "Haryana"): (29.6857, 76.9905),
        ("Wheat", "Karnal", "Haryana"): (29.6857, 76.9905),
        ("Rice", "Kurukshetra", "Haryana"): (29.9695, 76.8783),
        ("Wheat", "Kurukshetra", "Haryana"): (29.9695, 76.8783),
        ("Rice", "Ambala", "Haryana"): (30.3782, 76.7767),
        ("Mustard", "Bhiwani", "Haryana"): (28.7831, 76.1319),
        ("Cotton", "Sirsa", "Haryana"): (29.5349, 75.0298),
        ("Potato", "Agra", "Uttar Pradesh"): (27.1767, 78.0081),
        ("Onion", "Nashik", "Maharashtra"): (19.9975, 73.7898),
        ("Soybean", "Indore", "Madhya Pradesh"): (22.7196, 75.8577),
    }
    COMMODITIES = ["Rice", "Wheat", "Mustard", "Cotton", "Potato", "Onion", "Soybean"]


def predict_highest_orders(commodity_filter=None, days_ahead=7):
    """
    Evaluates all mandi corridors and ranks them by predicted order volume (kg)
    and price realization.
    """
    base_date = datetime.now()
    target_dt = (base_date + timedelta(days=days_ahead)).strftime("%Y-%m-%d")

    corridors_to_eval = []
    for (comm, dist, state), coords in CORRIDOR_COORDINATES.items():
        if commodity_filter and commodity_filter.strip().lower() not in ["all", "any", ""]:
            if comm.lower() == commodity_filter.strip().lower():
                corridors_to_eval.append((comm, dist, state, coords))
        else:
            corridors_to_eval.append((comm, dist, state, coords))

    if not corridors_to_eval:
        # Fallback to all corridors
        for (comm, dist, state), coords in CORRIDOR_COORDINATES.items():
            corridors_to_eval.append((comm, dist, state, coords))

    evaluations = []
    for comm, dist, state, coords in corridors_to_eval:
        try:
            res = predict_demand_and_price(comm, dist, target_dt, state)
            p50 = res["demand_forecast_kg"]["p50_expected"]
            p90 = res["demand_forecast_kg"]["p90_optimistic"]
            p10 = res["demand_forecast_kg"]["p10_pessimistic"]
            price = res["price_forecast_inr_per_kg"]["expected_modal_price"]
            min_p = res["price_forecast_inr_per_kg"]["min_price"]
            max_p = res["price_forecast_inr_per_kg"]["max_price"]

            surge_ratio = round(((p90 - p50) / p50) * 100, 1) if p50 > 0 else 0.0
            order_volume_value = round(p50 * price, 0)

            evaluations.append({
                "commodity": comm,
                "district": dist,
                "state": state,
                "market": coords.get("market", dist),
                "target_date": target_dt,
                "days_ahead": days_ahead,
                "p50_demand_kg": p50,
                "p90_surge_kg": p90,
                "p10_pessimistic_kg": p10,
                "expected_price_per_kg": price,
                "min_price_per_kg": min_p,
                "max_price_per_kg": max_p,
                "total_order_value_inr": order_volume_value,
                "surge_percent": surge_ratio,
                "actionable_insight": res["actionable_insight"],
                "recommendation": res["recommendation"]
            })
        except Exception as err:
            pass

    # Sort by highest expected demand volume (kg)
    evaluations.sort(key=lambda x: x["p50_demand_kg"], reverse=True)

    top_corridor = evaluations[0] if evaluations else None

    return {
        "status": "SUCCESS",
        "target_date": target_dt,
        "days_ahead": days_ahead,
        "commodity_filter": commodity_filter,
        "top_corridor": top_corridor,
        "all_ranked_corridors": evaluations
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Predict highest incoming agricultural orders")
    parser.add_argument("--commodity", type=str, default=None, help="Commodity: Tomato, Onion, Wheat or All")
    parser.add_argument("--days", type=int, default=7, help="Days ahead (default: 7)")
    parser.add_argument("--top", type=int, default=5, help="Number of top corridors to return (default: 5)")
    args = parser.parse_args()

    result = predict_highest_orders(commodity_filter=args.commodity, days_ahead=args.days)
    if args.top and "all_ranked_corridors" in result:
        result["all_ranked_corridors"] = result["all_ranked_corridors"][:args.top]
    print(json.dumps(result, indent=2))
