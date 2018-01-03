# Ruby 1.9 以降のみ!
# RAILS_ENV 環境変数を'test'に設定した状態で
'rails server'プロセスを開始する。 Process.spawn({'RAILS_ENV' => 'test'}, 'rails server')

# 'ls --zz' を実行している間、STDERR と STDOUT をマージする
Process.spawn('ls', '--zz', STDERR => STDOUT)