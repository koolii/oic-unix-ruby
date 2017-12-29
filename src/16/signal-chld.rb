child_processes = 3
dead_processes = 0

child_processes.times do
  fork do
    sleep 3
  end
end

# 親プロセスは思い計算処理で忙しくなるが、子プロセスの終了は検知したい
# :CHLDシグナルを補足し、子プロセスの終了時にカーネルからの通知を受信できる
trap(:CHLD) do
  # 終了した子プロセスの情報をProcess.waitで取得する
  puts Process.wait
  dead_process += 1

  exit if dead_processes == child_processses
end

# 重い計算処理
loop do
  (Math.sqrt(rand(44)) ** 8).floor
  sleep 1
end