"""R-023b economy sim (stdlib only). Plan: research/notes/R-023-economy.md §3.
Calibrates Rank costs on the regular profile, then tests all profiles. Hours = play hours."""
import json, random, statistics, pathlib

CFG = {
    "income": [600, 900, 1350, 1900, 2600],  # Shards per active hour at Rank 1..5 (zone tier)
    "upkeep": [40, 60, 90, 130, 180],  # Shards per hour (meals not gathered)
    "refill_cost": [10, 16, 26, 41, 66],  # per Qi refill (x1.6 per Rank)
    "stipend_day": [150, 240, 380, 610, 980],  # Clan stipend after Levy tax, per real day
    "crucible_every_h": 3, "catalyst": [100, 160, 260, 410, 660], "fail_p": 0.3,
    "cosmetic_frac": 0.05, "trade_frac": 0.2, "trade_fee": 0.05,
    "target_h": [2, 5, 12, 21],  # Rank 1->2, 2->3, 3->4, 4->5 (sum 40, GDD §6)
    "noise": 0.15, "dt": 0.25, "runs": 200, "capped_h": 100,
    "postcap": {"crucible_every_h": 1, "catalyst_mult": 2, "caravan_frac": 0.15},
}
PROFILES = {
    "casual": {"hpd": 0.5, "refills": 4, "trader": False},
    "regular": {"hpd": 2, "refills": 6, "trader": False},
    "grinder": {"hpd": 6, "refills": 6, "trader": False},
    "fighter": {"hpd": 2, "refills": 14, "trader": False},
    "trader": {"hpd": 2, "refills": 6, "trader": True},
}


def net_rate(c, p, r):
    crucible = c["catalyst"][r] / (c["crucible_every_h"] * (1 - c["fail_p"]))
    fixed = c["upkeep"][r] + p["refills"] * c["refill_cost"][r]
    inc = c["income"][r]
    other = inc * c["cosmetic_frac"] + (inc * c["trade_frac"] * c["trade_fee"] if p["trader"] else 0)
    return inc + c["stipend_day"][r] / p["hpd"] - fixed - crucible - other


def calibrate(c):
    reg = PROFILES["regular"]
    return [round(net_rate(c, reg, r) * c["target_h"][r], -2) for r in range(4)]


def run(c, p, costs, rng):
    r, prog, bal, t, next_day, next_cru = 0, 0.0, 0.0, 0.0, 0.0, c["crucible_every_h"]
    rank_t, sink, blocked = [], {"refine": 0, "fixed": 0, "crucible": 0, "other": 0}, False
    capped_start, cap_bal, cap_bal_ps = None, 0.0, 0.0
    while True:
        dt, capped = c["dt"], r >= 4
        if capped and capped_start is None:
            capped_start = t
        if capped and t - capped_start >= c["capped_h"]:
            break
        inc = c["income"][r] * (1 + rng.uniform(-c["noise"], c["noise"])) * dt
        if t >= next_day:
            inc += c["stipend_day"][r]; next_day += p["hpd"]
        fixed = (c["upkeep"][r] + p["refills"] * c["refill_cost"][r]) * dt
        other = c["income"][r] * dt * (c["cosmetic_frac"] + (c["trade_frac"] * c["trade_fee"] if p["trader"] else 0))
        cru = 0.0
        if t >= next_cru:
            cru = c["catalyst"][r]
            while rng.random() < c["fail_p"]:
                cru += c["catalyst"][r]
            next_cru += c["crucible_every_h"]
        net = inc - fixed - other - cru
        if not capped:
            if bal + net < 0:
                blocked = True
            sink["fixed"] += fixed; sink["crucible"] += cru; sink["other"] += other
            bal += net
            if bal > 0:
                prog += bal; sink["refine"] += bal; bal = 0
            if prog >= costs[r]:
                prog -= costs[r]; r += 1; rank_t.append(t + dt)
        else:
            cap_bal += net
            pc = c["postcap"]
            extra = c["income"][r] * dt * pc["caravan_frac"]
            if (t - capped_start) % pc["crucible_every_h"] < dt:
                extra += c["catalyst"][r] * pc["catalyst_mult"]
            cap_bal_ps += net - extra
        t += dt
    return rank_t, sink, blocked, cap_bal / c["capped_h"], cap_bal_ps / c["capped_h"]


def main():
    c = CFG
    costs = calibrate(c)
    rng = random.Random(42)
    out = {"rank_costs": costs, "cost_growth": [round(costs[i + 1] / costs[i], 2) for i in range(3)], "profiles": {}}
    for name, p in PROFILES.items():
        res = [run(c, p, costs, rng) for _ in range(c["runs"])]
        med = [round(statistics.median(x[0][i] for x in res), 1) for i in range(4)]
        s = res[0][1]; tot = sum(s.values())
        out["profiles"][name] = {
            "cum_h_to_rank2_5": med,
            "blocked_runs": sum(x[2] for x in res),
            "sink_share": {k: round(v / tot, 2) for k, v in s.items()},
            "capped_growth_per_h": round(statistics.median(x[3] for x in res)),
            "capped_growth_per_h_with_postcap_sinks": round(statistics.median(x[4] for x in res)),
        }
    tgt = [2, 7, 19, 40]
    reg = out["profiles"]["regular"]["cum_h_to_rank2_5"]
    out["regular_dev_pct"] = [round(100 * (a - b) / b) for a, b in zip(reg, tgt)]
    pathlib.Path(__file__).with_name("economy_results.json").write_text(json.dumps(out, indent=1))
    print("costs", costs, "growth", out["cost_growth"], "regular dev%", out["regular_dev_pct"])
    for n, v in out["profiles"].items():
        print(n, v["cum_h_to_rank2_5"], "blocked", v["blocked_runs"], "refine", v["sink_share"]["refine"],
              "cap/h", v["capped_growth_per_h"], "postcap/h", v["capped_growth_per_h_with_postcap_sinks"])


if __name__ == "__main__":
    main()