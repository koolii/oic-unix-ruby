# ブロックして外部コマンドを実行する
system 'sleep 5'
# ブロックせずに外部コマンドを実行する
Process.spawn 'sleep 5'
# Process.spawn を使いながらブロックするやり方。
# 子プロセスの pid が戻ってくることに注目。
pid = Process.spawn 'sleep 5'
Process.waitpid(pid)