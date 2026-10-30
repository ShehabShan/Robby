--!strict
-- Token-bucket rate limit (F-02, D-171). Pure: a bucket refills `rate` tokens per second up to `burst`;
-- each allowed call spends one token. Used by the server RemoteGuard for every client→server event.
-- No Roblox services.
local RateLimit = {}

export type Bucket = { tokens: number, at: number }

function RateLimit.new(burst: number, now: number): Bucket
	return { tokens = burst, at = now }
end

function RateLimit.allow(b: Bucket, now: number, rate: number, burst: number): boolean
	local dt = math.max(now - b.at, 0)
	b.tokens = math.min(burst, b.tokens + dt * rate)
	b.at = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

return RateLimit
