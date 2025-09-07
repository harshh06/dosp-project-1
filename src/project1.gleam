import gleam/bool
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

/// message types and state definitions
pub type WorkerMsg {
  Work(start: Int, end: Int, k: Int, reply_to: process.Subject(BossMsg))
  // start and end define the range to check
  // k is the number of consecutive squares to sum
  // reply_to is where to send results
  Stop
}

pub type BossMsg {
  Solutions(solutions: List(Int), worker_id: Int)
  // solutions found by the worker
}

type WorkerState {
  WorkerState(id: Int)
}

pub type BossState {
  BossState(
    solutions: List(Int),
    // solutions found so far
    queue: List(#(Int, Int)),
    // work chunks waiting to be assigned
    workers: List(#(Int, process.Subject(WorkerMsg))),
    // available workers
    inflight: Int,
    // number of active work items
    to_stop: Int,
    // number of workers to stop
  )
}

/// square sum logic functions
// calculate the sum of squares from start to start + k - 1

fn sum_consecutive_squares(start: Int, k: Int) -> Int {
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
fn is_perfect_square(n: Int) -> Bool {
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
fn find_solutions_in_range(start: Int, end: Int, k: Int) -> List(Int) {
  list.range(start, end)
  |> list.filter(fn(i) {
    let sum = sum_consecutive_squares(i, k)
    is_perfect_square(sum)
  })
}

/// worker actor functions
// worker message handler: processes incoming messages

fn worker_handle(
  state: WorkerState,
  msg: WorkerMsg,
) -> actor.Next(WorkerState, WorkerMsg) {
  case msg {
    Work(start, end, k, reply) -> {
      // find solutions in the assigned range
      let solutions = find_solutions_in_range(start, end, k)

      // io.println(
      //   "Worker "
      //   <> int.to_string(state.id)
      //   <> " processed range "
      //   <> int.to_string(start)
      //   <> " to "
      //   <> int.to_string(end)
      //   <> ", found "
      //   <> int.to_string(list.length(solutions))
      //   <> " solutions.",
      // )

      // send the solutions back to the boss
      process.send(reply, Solutions(solutions, state.id))
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}

// start a worker actor
fn start_worker(id: Int) -> Result(process.Subject(WorkerMsg), actor.StartError) {
  let actor_result =
    actor.new(WorkerState(id))
    |> actor.on_message(worker_handle)
    |> actor.start()

  case actor_result {
    Ok(started) -> Ok(started.data)
    // started.data is the worker's message subject
    Error(err) -> Error(err)
  }
}

/// boss actor functions
// create work chunks of given size

fn chunkify(n: Int, work_unit_size: Int) -> List(#(Int, Int)) {
  chunkify_helper(1, n, work_unit_size, [])
}

fn chunkify_helper(
  i: Int,
  n: Int,
  work_unit_size: Int,
  acc: List(#(Int, Int)),
) -> List(#(Int, Int)) {
  case i > n {
    True -> list.reverse(acc)
    False -> {
      let hi = int.min(i + work_unit_size - 1, n)
      chunkify_helper(hi + 1, n, work_unit_size, [#(i, hi), ..acc])
    }
  }
}

// assign work to a specific worker
fn assign_work(
  state: BossState,
  worker_subject: process.Subject(WorkerMsg),
  boss_inbox: process.Subject(BossMsg),
  k: Int,
  // 添加k参数
) -> BossState {
  case state.queue {
    [] -> {
      // 没有更多工作 - 告诉worker停止
      process.send(worker_subject, Stop)
      BossState(..state, to_stop: state.to_stop - 1)
    }
    [head, ..rest] -> {
      // 分配工作块给worker
      let #(start, end) = head
      process.send(worker_subject, Work(start, end, k, boss_inbox))
      BossState(..state, queue: rest, inflight: state.inflight + 1)
    }
  }
}

fn find_worker(
  workers: List(#(Int, process.Subject(WorkerMsg))),
  worker_id: Int,
) -> Result(#(Int, process.Subject(WorkerMsg)), Nil) {
  list.find(workers, fn(pair) { pair.0 == worker_id })
}

fn coordinate_work(
  state: BossState,
  boss_inbox: process.Subject(BossMsg),
  k: Int,
) -> List(Int) {
  case state.inflight > 0 || state.to_stop > 0 {
    False -> state.solutions
    // 所有工作完成！
    True -> {
      // 等待worker报告
      case process.receive(boss_inbox, within: 30_000) {
        Ok(Solutions(new_solutions, worker_id)) -> {
          let updated_solutions = list.append(state.solutions, new_solutions)
          let new_inflight = state.inflight - 1

          // 给这个worker分配更多工作
          case find_worker(state.workers, worker_id) {
            Ok(#(_, worker_subject)) -> {
              let new_state =
                BossState(
                  ..state,
                  solutions: updated_solutions,
                  inflight: new_inflight,
                )
              let assigned_state =
                assign_work(new_state, worker_subject, boss_inbox, k)
              coordinate_work(assigned_state, boss_inbox, k)
            }
            Error(_) -> {
              let new_state =
                BossState(
                  ..state,
                  solutions: updated_solutions,
                  inflight: new_inflight,
                )
              coordinate_work(new_state, boss_inbox, k)
            }
          }
        }
        Error(_) -> {
          io.println("等待worker响应超时")
          state.solutions
        }
      }
    }
  }
}

/// benchmark and main functions
// get current system time in milliseconds

@external(erlang, "erlang", "system_time")
fn system_time_native() -> Int

pub fn system_time() -> Int {
  system_time_native() / 1_000_000
  // convert to milliseconds
}

// test performance with different work unit sizes
fn test_work_unit_size(
  n: Int,
  k: Int,
  num_workers: Int,
  work_unit_size: Int,
) -> #(List(Int), Int) {
  io.println(
    "\n=== test work unit size: " <> int.to_string(work_unit_size) <> " ===",
  )

  let start_time = system_time()
  let boss_inbox = process.new_subject()

  // create workers
  let workers =
    list.range(1, num_workers)
    |> list.filter_map(fn(id) {
      case start_worker(id) {
        Ok(worker_subject) -> Ok(#(id, worker_subject))
        Error(_) -> {
          io.println("Failed to start worker " <> int.to_string(id))
          Error(Nil)
        }
      }
    })

  let actual_workers = list.length(workers)
  io.println(
    "Successfully started " <> int.to_string(actual_workers) <> " workers",
  )

  // create work queue
  let work_queue = chunkify(n, work_unit_size)
  io.println(
    "Created " <> int.to_string(list.length(work_queue)) <> " work chunks",
  )

  // initial state
  let initial_state =
    BossState(
      solutions: [],
      queue: work_queue,
      workers: workers,
      inflight: 0,
      to_stop: actual_workers,
    )

  // assign initial work to each worker
  let state_after_initial_assignment =
    list.fold(workers, initial_state, fn(state, worker) {
      let #(_, worker_subject) = worker
      assign_work(state, worker_subject, boss_inbox, k)
    })

  // start coordinating work
  let solutions = coordinate_work(state_after_initial_assignment, boss_inbox, k)

  let end_time = system_time()
  let duration = end_time - start_time

  io.println("Found " <> int.to_string(list.length(solutions)) <> " solutions")
  io.println("Duration: " <> int.to_string(duration) <> " ms")

  #(solutions, duration)
}

pub fn main() {
  // test cases
  let n = 100
  let k = 24
  let num_workers = 4

  io.println("=== square sum problem solver ===")
  io.println(
    "Problem: Find all starting points i (1 ≤ i ≤ " <> int.to_string(n) <> ")",
  )
  io.println(
    "such that i² + (i+1)² + ... + (i+"
    <> int.to_string(k - 1)
    <> ")² = a perfect square",
  )
  io.println("Using " <> int.to_string(num_workers) <> " workers")

  // test different work unit sizes to find the best one
  let work_unit_sizes = [100, 500, 1000, 2000, 5000, 10_000]

  let results =
    list.map(work_unit_sizes, fn(work_unit_size) {
      let #(solutions, time) =
        test_work_unit_size(n, k, num_workers, work_unit_size)
      #(work_unit_size, solutions, time)
    })

  // find the best result
  let best_result =
    list.fold(results, #(0, [], 999_999), fn(best, current) {
      let #(_, _, best_time) = best
      let #(_, _, current_time) = current
      case current_time < best_time {
        True -> current
        False -> best
      }
    })

  let #(best_work_unit_size, final_solutions, best_time) = best_result

  io.println("\n=== Best Result ===")
  io.println("Best work unit size: " <> int.to_string(best_work_unit_size))
  io.println("Best execution time: " <> int.to_string(best_time) <> " ms")
  io.println("Found solutions:")
  list.each(final_solutions, fn(solution) {
    io.println(int.to_string(solution))
  })
  // io.println(bool.to_string(is_perfect_square(13)))
}
