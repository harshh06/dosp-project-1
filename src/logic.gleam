import gleam/int
import gleam/list
// import gleam/io


pub fn range (st: Int, end: Int) -> List(Int) {
  case st > end {
    True -> []
    False -> [st, ..range(st + 1,end)]
  }
}

pub fn sq_sum (n: Int) -> Int {
  let first_term = n + 1
    let second_term =  2*n + 1
    let product = int.multiply(
      int.multiply(n, first_term),
      second_term
    )
    let sum = product / 6
    sum
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
    let st = i-1
    let end = i+k-1
    let sq_sum_st = sq_sum(st)
    let sq_sum_end = sq_sum(end)
    let sum = sq_sum_end - sq_sum_st
    p_sq(sum)
  })
}


// pub fn main() -> Nil {
//   let n = 40
//   let k = 24
//   let list_of_nums = range(1, n)

//   let p_sqs = process_p_sq(list_of_nums, k)

//   list.each(p_sqs, fn(i: Int) {
//     io.println(int.to_string(i))
//   })


//   Nil

// }
