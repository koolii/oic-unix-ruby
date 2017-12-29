child_processes = 3
dead_processes = 0

child_processes.times do
  fork do
    sleep 3
  end
end

# CHLDハンドラの中でputsの出力をバッファリングしないように
# $stdoutの出力を同期モードに設定することで、もしputsを呼出した後に
# シグナルハンドラが中断された場合はThreadErrorがスローされる
$stdout.sync = true

# 親プロセスは思い計算処理で忙しくなるが、子プロセスの終了は検知したい
# :CHLDシグナルを補足し、子プロセスの終了時にカーネルからの通知を受信できる
trap(:CHLD) do
  # 終了した子プロセスの情報をProcess.waitで取得する
  # ブロックせずにProcess.waitをループさせることで子プロセスの終了を見逃さないようにする
  begin
    while pid = Process.wait(-1, Process::WNOHANG)
      puts pid
      dead_process += 1
    end
  rescue Errno::ECHILD
  end
end

# 重い計算処理
loop do
  # すべての子プロセスが終了した時点で明示的に親プロセスを終了
  exit if dead_processes == child_processses
  sleep 1
end