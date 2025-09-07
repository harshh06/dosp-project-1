import gleam/list

pub fn range(st: Int, end: Int) -> List(Int) {
  case st > end {
    True -> []
    False -> [st, ..range(st + 1, end)]
  }
}

// Fixed sq_sum function - avoid overflow for large numbers
pub fn sq_sum(n: Int) -> Int {
  // Use the formula: n(n+1)(2n+1)/6
  // But be careful about order of operations to avoid overflow
  case n % 6 {
    0 -> {
      let first = n / 6
      let second = n + 1
      let third = 2 * n + 1
      first * second * third
    }
    3 -> {
      let first = n
      let second = { n + 1 } / 6
      let third = 2 * n + 1
      first * second * third
    }
    _ -> {
      // Fallback - might still overflow for very large n
      let numerator = n * { n + 1 } * { 2 * n + 1 }
      numerator / 6
    }
  }
}

pub fn binary_search(st: Int, end: Int, n: Int) -> Bool {
  case st > end {
    True -> False
    False -> {
      let sum = st + end
      let mid = sum / 2
      let product = mid * mid
      case product {
        product if product == n -> True
        product if product < n -> binary_search(mid + 1, end, n)
        _ -> binary_search(st, mid - 1, n)
      }
    }
  }
}

pub fn p_sq(n: Int) -> Bool {
  case n {
    n if n < 0 -> False
    0 -> False
    1 -> True
    _ -> binary_search(0, n / 2 + 1, n)
  }
}

pub fn process_p_sq(list_nums: List(Int), k: Int) -> List(Int) {
  list.filter(list_nums, fn(i: Int) -> Bool {
    let st = i - 1
    let end = i + k - 1
    let sq_sum_st = sq_sum(st)
    let sq_sum_end = sq_sum(end)
    let sum = sq_sum_end - sq_sum_st
    p_sq(sum)
  })
}
