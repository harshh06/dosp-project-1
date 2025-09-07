import gleam/io
import gleam/erlang/process
import gleam/otp/actor
import gleam/int
import gleam/list
import argv
import gleam/result
import logic
import helpers


// Worker messages
pub type WorkerMsg {
  Work(start: Int, stop: Int, k: Int, reply_to: process.Subject(BossMsg))
  Stop
}

pub type BossMsg {
  BossMsg(result: List(Int), worker_id: Int)
}

type WorkerState { 
  WorkerState(id: Int) 
}

// Boss state for dynamic work queue
pub type BossState {
  BossState(
    total: List(Int),
    queue: List(#(Int, Int)),                        // Work chunks waiting to be assigned
    workers: List(#(Int, process.Subject(WorkerMsg))), // Available workers
    inflight: Int,                                   // Number of active work items
    to_stop: Int                                     // Workers still to stop
  )
}

fn worker_handle(state: WorkerState, msg: WorkerMsg) -> actor.Next(WorkerState, WorkerMsg) {
  case msg {
    Work(start, stop, k, reply) -> {
      let list_of_nums = logic.range(start, stop)
      let p_sqs = logic.process_p_sq(list_of_nums, k)
      // let sum = sum_range(start, stop)
      process.send(reply, BossMsg(p_sqs, state.id))
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}

fn start_worker(id: Int) -> Result(process.Subject(WorkerMsg), actor.StartError) {
  let actor_result = 
    actor.new(WorkerState(id))
    |> actor.on_message(worker_handle)
    |> actor.start()
  
  case actor_result {
    Ok(started) -> Ok(started.data)
    Error(err) -> Error(err)
  }
}

// Assign work to a specific worker
fn assign_work(
  state: BossState, 
  _worker_id: Int, 
  worker_subject: process.Subject(WorkerMsg),
  boss_inbox: process.Subject(BossMsg),
  k: Int
) -> BossState {
  case state.queue {
    [] -> {
      // No more work - tell worker to stop
      process.send(worker_subject, Stop)
      BossState(..state, to_stop: state.to_stop - 1)
    }
    [head, ..rest] -> {
      // Assign work chunk to worker
      let #(lo, hi) = head
      process.send(worker_subject, Work(lo, hi, k, boss_inbox))
      BossState(..state, queue: rest, inflight: state.inflight + 1)
    }
  }
}

fn find_worker(workers: List(#(Int, process.Subject(WorkerMsg))), worker_id: Int) -> Result(#(Int, process.Subject(WorkerMsg)), Nil) {
  list.find(workers, fn(pair) { pair.0 == worker_id })
}

// Dynamic work coordination - workers get more work when they finish
fn coordinate_work(state: BossState, boss_inbox: process.Subject(BossMsg), k: Int) -> List(Int) {
  case state.inflight > 0 || state.to_stop > 0 {
    False -> state.total  // All done!
    True -> {
      case process.receive(boss_inbox, within: 5000) {
        Ok(BossMsg(result, worker_id)) -> {
          let new_total = list.append(state.total, result)

          let new_inflight = state.inflight - 1
          
          // Give this worker more work immediately!
          case find_worker(state.workers, worker_id) {
            Ok(#(_, worker_subject)) -> {
              let new_state = BossState(
                ..state, 
                total: new_total, 
                inflight: new_inflight
              )
              let assigned_state = assign_work(new_state, worker_id, worker_subject, boss_inbox, k)
              coordinate_work(assigned_state, boss_inbox, k)
            }
            Error(_) -> {
              let new_state = BossState(..state, total: new_total, inflight: new_inflight)
              coordinate_work(new_state, boss_inbox, k)
            }
          }
        }
        Error(_) -> {
          io.println("Timeout waiting for worker response")
          state.total
        }
      }
    }
  }
}



// DYNAMIC WORK QUEUE VERSION
fn benchmark_workers_dynamic(n: Int, num_workers: Int, chunk_size: Int, k: Int) -> Nil {
  // io.println("Testing " <> int.to_string(num_workers) <> " workers with dynamic work queue...")
  // io.println("Chunk size: " <> int.to_string(chunk_size) <> " (creates " <> int.to_string(n / chunk_size) <> " chunks)")
  
  // let start_time = helpers.system_time()
  let boss_inbox = process.new_subject()
  
  // Start workers
  let workers = list.range(1, num_workers)
    |> list.filter_map(fn(id) {
      case start_worker(id) {
        Ok(worker) -> Ok(#(id, worker))
        Error(_) -> {
          io.println("Failed to start worker " <> int.to_string(id))
          Error(Nil)
        }
      }
    })
  
  let actual_workers = list.length(workers)
  
  // Create work queue with many small chunks
  let work_chunks = helpers.create_work_chunks(n, chunk_size)
  let _total_chunks = list.length(work_chunks)
  
  // io.println("Created " <> int.to_string(total_chunks) <> " work chunks")
  
  // Initialize boss state
  let initial_state = BossState(
    total: [],
    queue: work_chunks,
    workers: workers,
    inflight: 0,
    to_stop: actual_workers
  )
  
  // Start by giving each worker their first chunk
  let state_with_initial_work = list.fold(workers, initial_state, fn(state, worker) {
    let #(worker_id, worker_subject) = worker
    assign_work(state, worker_id, worker_subject, boss_inbox, k)
  })
  
  // Let the dynamic coordination begin!
  let final_result = coordinate_work(state_with_initial_work, boss_inbox, k)
  
  // let end_time = helpers.system_time()
  // let duration = end_time - start_time
  
  // io.println("Time: " <> int.to_string(duration) <> " ms")
  list.each(final_result, fn(i: Int) {
    io.println(int.to_string(i))
  })
  // io.println("Result: " <> int.to_string(final_result))
  
  // #(final_result, duration)
}


pub fn main() {
   let args = argv.load().arguments
  
  // Simple extraction
  let _name = case args {
    [n, ..] -> n
    _ -> "default"
  }
  let n = case args {
    [_, n_str, ..] -> int.parse(n_str) |> result.unwrap(1000000)
    _ -> 1000000
  }
  let k = case args {
    [_, _, k_str, ..] -> int.parse(k_str) |> result.unwrap(50000)
    _ -> 50000
  }
  
  // Use them
  // io.println("Name: " <> name)
  // io.println("N: " <> int.to_string(n)) 
  // io.println("K: " <> int.to_string(k))
  // let n = 100_000_000
  let chunk_size = helpers.calculate_optimal_chunk_size(n, 8)
  
  // io.println("=== DYNAMIC WORK QUEUE BENCHMARK ===")
  // io.println("Problem: Sum numbers 1 to " <> int.to_string(n))
  // io.println("Strategy: Workers get new work as soon as they finish")
  // io.println("")
  
  benchmark_workers_dynamic(n, 8, chunk_size, k)

  
}