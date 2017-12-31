reader, writer = IO.pipe

# 注意しないといけないのは子プロセスにファイルディスクリプタが
# ２つ複製されてしまうので、４つの実態が存在していることになる
# その内通信に使うのは２つだけなので残りの２つは閉じている
fork do
  reader.close

  10.times do |i|
    # 力仕事
    writer.puts "#{i+1}: Another one bites the dust"
  end
end

writer.close
while message = reader.gets
  $stdout.puts message
end