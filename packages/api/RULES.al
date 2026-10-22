# prove-with: src/kernels.al
# BunnyApi invariants, proven by exhaustion (`alice prove RULES.al src/kernels.al`).

# Any page request on any list stays in bounds: no negative ranges, no overflow past the end,
# never more than one page, and the pages partition the list.
rule page_window_in_bounds(total in 0..400, page in -3..60, per in -2..130)
start = BunnyApi::Kernels.window_start(total, page, per)
count = BunnyApi::Kernels.window_count(total, page, per)
q = BunnyApi::Kernels.per_page(per)
start >= 0 && count >= 0 && start + count <= total && count <= q && q >= 1 && q <= 100
end

# Pages before the last are full; total_pages pages cover exactly `total` entries.
rule pages_cover_total(total in 0..400, per in 1..120)
pages = BunnyApi::Kernels.total_pages(total, per)
sum = 0
for p in 1..pages
  c = BunnyApi::Kernels.window_count(total, p, per)
  return false if p < pages && c != BunnyApi::Kernels.per_page(per)
  sum += c
end
sum == total && BunnyApi::Kernels.window_count(total, pages + 1, per) == 0
end
