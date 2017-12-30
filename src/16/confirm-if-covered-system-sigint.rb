# Ctrl-CのSIGINTが保存されず、エラーが発生してしまう
# 確認方法はこのRubyファイルを実行し、そのままCtrl-Cを実行する
system_handler = trap(:INT) {
  puts 'about to exit!!'
  system_handler.call
}

sleep 5