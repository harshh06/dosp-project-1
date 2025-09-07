import gleam/int
import gleam/io
import gleam/float
import gleam/list

pub fn calculate_optimal_chunk_size(n: Int, num_workers: Int) -> Int {
  case n, num_workers {
    // Edge cases
    n, _ if n <= 0 -> 1
    _, workers if workers <= 0 -> n
    
    // TINY inputs (n=3, k=2 type cases)
    n, _ if n <= 10 -> 1  // Each number is its own chunk
    
    // SMALL inputs (n=11 to 1000) 
    n, workers if n <= 1000 -> {
      let target_chunks = workers * 2  // Only 2 chunks per worker
      let chunk_size = int.max(1, n / target_chunks)
      chunk_size
    }
    
    // MEDIUM inputs (n=1001 to 100,000)
    n, workers if n <= 100000 -> {
      let target_chunks = workers * 4
      let chunk_size = n / target_chunks
      int.max(10, chunk_size)  // At least 10 per chunk
    }
    
    // LARGE inputs (n > 100,000)
    n, workers -> {
      let target_chunks = workers * 5
      let chunk_size = n / target_chunks
      // Keep your existing bounds for large problems
      let min_chunk = 1000
      let max_chunk = int.min(50000, n / workers)
      
      case chunk_size {
        size if size < min_chunk -> min_chunk
        size if size > max_chunk -> max_chunk
        size -> size
      }
    }
  }
}
@external(erlang, "erlang", "system_time")
fn system_time_native() -> Int

pub fn system_time() -> Int {
  system_time_native() / 1_000_000  // Convert nanoseconds to milliseconds
}

 // Helper: Calculate speedup compared to baseline
pub fn calculate_speedup(baseline_time: Int, current_time: Int, workers: Int) {
  case baseline_time > 0, current_time > 0 {
    True, True -> {
      let speedup = int.to_float(baseline_time) /. int.to_float(current_time)
      let efficiency = speedup /. int.to_float(workers) *. 100.0
      
      let speedup_display = float.round(speedup *. 100.0) / 100
      
      let efficiency_display = float.round(efficiency)
      
      io.println("Speedup: " <> int.to_string(speedup_display) <> "x")
      io.println("Efficiency: " <> int.to_string(efficiency_display) <> "%")
    }
    _, _ -> io.println("Cannot calculate speedup")
  }
}


// Create MANY small chunks (not based on number of workers!)
pub fn create_work_chunks(n: Int, chunk_size: Int) -> List(#(Int, Int)) {
  create_chunks_helper(1, n, chunk_size, [])
}

pub fn create_chunks_helper(start: Int, n: Int, chunk_size: Int, acc: List(#(Int, Int))) -> List(#(Int, Int)) {
  case start > n {
    True -> list.reverse(acc)
    False -> {
      let end = int.min(start + chunk_size - 1, n)
      create_chunks_helper(end + 1, n, chunk_size, [#(start, end), ..acc])
    }
  }
}
