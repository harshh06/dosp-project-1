import gleam/float
import gleam/int
import gleam/list

// calculate the sum of squares from start to start + k - 1

pub fn sum_consecutive_squares(start: Int, k: Int) -> Int {
  // list.range(start, start + k - 1)
  // |> list.fold(0, fn(acc, n) { acc + n * n })

  // Using the formula: sum of squares from 1 to n is n(n+1)(2n+1)/6
  let end = start + k - 1
  end
  * { end + 1 }
  * { 2 * end + 1 }
  / 6
  - { start - 1 }
  * start
  * { 2 * { start - 1 } + 1 }
  / 6
}

// check if n is a perfect square
pub fn is_perfect_square(n: Int) -> Bool {
  let sqrt_n = int.square_root(n)
  case sqrt_n {
    Ok(root) -> {
      let int_root = float.round(root)
      // nearest integer to the square root
      let ans = int_root * int_root == n
      // case ans {
      //   True -> io.println("Found perfect square: " <> int.to_string(n))
      //   False -> Nil
      // }
      ans
    }
    Error(_) -> False
  }
}

// worker's main logic to find solutions in a given range
pub fn find_solutions_in_range(start: Int, end: Int, k: Int) -> List(Int) {
  list.range(start, end)
  |> list.filter(fn(i) {
    let sum = sum_consecutive_squares(i, k)
    is_perfect_square(sum)
  })
}
