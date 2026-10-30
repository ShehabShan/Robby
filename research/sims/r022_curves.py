"""R-022 curve check: TTK and build spread for the draft damage model. Run: python3 research/sims/r022_curves.py"""

def potency(rank, stage=0):
    return 1.6 ** (rank - 1) * (1 + 0.1 * stage)

def k(rank):
    return 50 * 1.6 ** (rank - 1)

def marks_boost(m):
    return 0.6 * m / (m + 60)

def dps(rank, stage, marks=0, surge=1.0, base=20, hits_per_s=1.5):
    surge = min(surge, 3.0)  # Surge cap
    return base * hits_per_s * potency(rank, stage) * (1 + marks_boost(marks)) * surge

def enemy_hp(rank, stage=0):
    return 300 * potency(rank, stage)

def taken(raw, attacker_rank, guard):
    return raw * k(attacker_rank) / (k(attacker_rank) + guard)

fresh = dict(marks=0, surge=1.0)
best = dict(marks=60, surge=1.20 * 1.3 * 1.3 * 1.12)  # Paragon + 2 strong supports + Path Ground

print("TTK (s) player Rank1 First vs enemy, fresh / best build")
for gap in (0, 1, 2):
    hp = enemy_hp(1 + gap)
    print(f"  enemy +{gap} Rank: {hp / dps(1, 0, **fresh):5.1f} / {hp / dps(1, 0, **best):5.1f}")
print(f"best/fresh DPS ratio: {dps(1,0,**best)/dps(1,0,**fresh):.2f} (target <= 3)")
print("Marks boost at 10/30/60/200:", [round(marks_boost(m), 2) for m in (10, 30, 60, 200)])
print("Guard 50 vs same-Rank / +2 Rank hit of 100:", round(taken(100, 1, 50)), "/", round(taken(100, 3, 50)))
print("Peak->next First jump:", round(potency(2, 0) / potency(1, 3), 2))