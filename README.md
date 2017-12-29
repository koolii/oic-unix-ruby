# なるほどUnixプロセス(Ruby)

## ２章
* カーネルとのやりとりは全てシステムコール経由でなければならない
* システムコールのインターフェースがカーネルとユーザーランドとを取り次ぐ
* ユーザーランドは、あなたの書いたプログラムが実行される場所
* あらゆるコードはプロセス上で実行される

## ３章
* プロセスの現在のpidはグローバル変数$$にも保持されているし、Process.pid(getpid(2)に対応)でも取得できる

## ４章
* プロセスの親のpidはProcess.ppid(getppid(2)に対応している)で取得できる

## ５章
* Rubyでは、開いたリソースはIOクラスで表現している、IOオブジェクトは自身のファイルディスクリプタを知っていて、IO#filenoで取得できる

```ruby
# 開いている最小の番号がディスクリプタに割り当てられる(0-2は標準入出力エラー)
passwd = File.open('/etc/passwd')
puts passwd.fileno # => 3

hosts = File.open('/etc/hosts')
puts hosts.fileno # => 4

# ファイルをクローズ(ファイルディスクリプタを閉じることになるため、番号は開放される)
passwd.close

null = File.open('/dev/null')
puts null.fileno # => 3
```

## ６章
一つのプロセスでファイルディスクリプタはいくつ開けるのだろうか。
まず、ファイルディスクリプタはソフトリミットとハードリミットが存在し、ソフトリミットを超えると例外が発生する
ハードリミットは無限大くらい大きい値になっていて、ハードリミットに達する前にハードの方が壊れてしまう方が早い

また、これらの値はRubyのコードから任意の値に変更することが可能
下記の様なコードは一つのプロセスが同時に数千のネットワークコネクションを扱う必要がある場合などに有効利用ができる

```ruby
# オープンできるファイルの最大数を3に設定
# 標準ストリームでファイルディスクリプタを3つ使うため、すでに上限に達している
Process.setrlimit(:NOFILE, 3)
File.open('/dev/null')o

# => Errno::EMFILE: Too many open files - /dev/null
#	from (irb):2:in `initialize'
#	from (irb):2:in `open'
#	from (irb):2
#	from /usr/bin/irb:12:in `<main>'

# プロセスのユーザが作成できる最大プロセス数
Process.getrlimit(:NPRO)
# プロセスが作成できるファイルサイズの最大値
Process.getrlimit(:FSIZE)
# プロセススタックの最大サイズ
Process.getrlimit(:STACK)
```

## ７章
環境変数はハッシュのようになっているが、メソッドなどが備わっておらず、ハッシュとは言いにくい
これらはRubyのENVと言うグローバル変数などのコマンドラインツールの入力に渡す方法としてよく使われる

## ８章
RubyプロセスはARGVという特別な配列(Array)を持っている
よく使われるのは例に漏れず、プログラムにファイル名を渡したい場合
Rubyにはコマンドライン引数の解析ライブラリがいくつもあるが、簡単なフラグ程度なら、配列を直接操作して実装してみるのも良さげ

## ９章
irbコマンドを入力すると、プロセスの名前は「irb」となるが、Rubyの環境変数を変更することでプロセス名を変更することが可能
プロセス名の有効活用例は「Resqueのプロセス管理」とのこと。（まだそこまで読み進めていない）

```ruby
puts $PROGRAM_NAME

10..downto(1) do |num|
  $PROGRAM_NAME = "Process: #{num}"
  puts $PROGRAM_NAME
end
```

## １０章
プロセスの終了で一番簡単なのはKernel#exitを使って正常終了させること（任意の終了コードで終わらせることもできる）
Kernel#at_exitで定義された全てのブロックが呼び出される
Kernel#exit!(!= Kernel#exit)は終了コードのデフォルトが異常終了(1)で、Kernel#at_exitで定義されたブロックは実行されない
Kernel#abortは問題のあったプロセスを終了させる場合によく使われる
Kernel#raiseは例外として扱われるのですぐにはプロセスが終了しない

## １１章
fork(2)して子プロセスを生成することはUnixプログラミングで最も強力な考え方の１つ
実行中のプロセスから新しいプロセスを生成できる、新プロセスは元プロセスの完全なコピー
子プロセスは親プロセスで使われている全てのメモリのコピーを引き継ぐ、親プロセスが開いているファイルディスクリプタも同様に引き継ぐ
なので、２つのプロセスで開いているファイルやソケットなどを共有出来るということ
Railsの様にメモリ上に巨大なソフトウェアのコピーを効率的に持つことが出来るのでアプリケーションのインスタンスを複数同時に立ち上げるのが便利
なぜなら、アプリケーションを読み込む必要があるプロセスは一つだけで、forkも早いから、同じアプリケーションを別々に読み込むより早い

ブロック付きでforkメソッドを呼出した場合、ブロックは子プロセスのみで実行されて、親プロセスでは無視される、子プロセスはブロック内の処理が終わったらそこで終了し、親プロセス皮の処理は続行しない
実用的な活用法は付録やSpyglassを参照する

```ruby
fork do
  # 子プロセスで実行する処理を個々に記述する
end

# 親プロセスで実行する処理を個々に記述する
```

## １２章
端末からプロセスを作成し、複数のプロセスが存在した上でCtrl+Cでプロセスを終了させた時に、親プロセスは死ぬが、子プロセスによってSTDOUTが上書きされてしまう(奇妙)
よって、子プロセスには「何もおきない」、OS側は親プロセスが死ぬ時に子プロセスを道連れにしない

```ruby
fork do
  5.times do
    sleep 1
    puts "I'm an orphan!"
  end
end

abort "Parent process died..."
```

### １３章
Unixのシステムは物理的に全てのデータをコピーするのはかなりのオーバーヘッドになる為、コピーオンライト(CoW, Copy on Write)と言う仕組みを採用している
CoWは書き込みが必要になるまでメモリを実際にコピーするのを遅らせ、その間は親プロセスと子プロセスはメモリ上の同じデータを物理的に共有する
親または子で変更する必要が生じた時だけメモリをコピーすることで整合性を保っている

CoWはfork(2)する時にリソースを節約出来るのですごく便利、

```ruby
arr = [1,2,3]

fork do
  # ここで子プロセスが初期化
  # arrはコピーせず参照することができる
  p arr

  # この行は配列に変更を加えるので、実際に変更を加える前に
  # 子プロセス用に配列のコピーが必要になる、親プロセス側での配列は変更されない
  arr << 4
end
```

## １４章
fork(2)の例では、例えば、子プロセスよりも先に親プロセスが終了してしまった場合に奇妙な結果をもたらす
そうした使い方が適切なのはプロセスを「打ちっぱなし(fire and forget)」でも構わないケースのみ

子プロセス側で非同期に処理をさせたくて、親プロセス側では独自に処理を進めたい場合に「打ちっぱなし」がうまくいく

```ruby
message = 'Good Morning'
receipient = 'tree@mybackyard.com'

fork do
  # 子プロセスを生成して統計収集機にdataを送信して、親プロセスは実際のメッセージ送信処理をそのまま続ける
  # 親プロセスとしては、この作業で処理が遅くなってほしくないし、統計収集機への送信が何らかの理由で失敗したとしても気にしなくなる
  StatsCollector.record message, recipient
end

# 実際の宛先にメッセージを送信する
```

↑以外だと殆どが子プロセスを敵的に管理できる何らかの仕組みが必要になると思われる
Rubyではその方法の１つとしてProcess.waitが提供されている
Process.waitは子プロセスのどれか１つが終了するまでの間、親プロセスをブロックして待機する

```ruby
fork do
  5.times do
    sleep 1
    puts "I am an orphan!"
  end
end

Process.wait
abort "Parent process died..."
```

Process.waitは親プロセスをブロックし、子プロセスを実行するが、複数の子プロセスを作成した時の為にはProcess.waitの戻り値を使って判断する

```ruby
3.times do
  fork do
    # 各プロセス毎に5秒未満でランダムにスリープ
    sleep rand(5)
  end
end

3.times do
  # 子プロセス夫々の終了を待ち、帰ってきたpidを出力
  puts Process.wait
end
```

Process.wait2というメッソドも存在し、これは返値にpidと終了ステータスの2つを返す
Process.wait2から返される終了ステータスはProcess::Statusクラスのインスタンスで
どのようにプロセスが終了したのかを正確に知るための情報を保持する

```ruby
5.times do
  fork do
    # 子プロセス毎にランダムな値を生成
    # 偶数なら111を、基数なら112を終了コードして返す
    if rand(5).even?
      exit 111
    else
      exit 112
    end
  end
end

5.times do
  pid, status = Process.wait2

  if status.exitstatus == 111
    puts "#{pid} encountered an even number!"
  else
    puts "#{pid} encountered an even number!"
  end
end
```

Process.wait2の他にもProcess.waitpidとProcess.waitpid2というのも存在していて、
これらは指定した子プロセスの終了を待つという役割を持っている

```ruby
favorite = fork do
  exit 77
end

middle_child = fork do
  abort "I want to be waited on!"
end

pid, status = Process.waitpid2 favorite
puts status.exitstatus
```

終了したプロセスを扱ってる最中に別のプロセスが終了したら？
Proces.waitにたどり着いていないのに別の子プロセスが終了したら？
実際はキューの仕組みになっているので、親がどのタイミングでwaitしても問題はない
※ ただ、子プロセスが一つもない状態でProcess.waitを呼ぶと例外がスローされるので注意

```ruby
```

```ruby
2.times do
  fork do
    # いずれもすぐに終了する
    abort "Finished!"
  end
end

# スリープしている間に２つのコプセスが終了する
puts Process.wait
sleep 5

# 親プロセスで再びwaitすると
# ２つ目の子プロセスの終了情報がここに帰ってくる
puts Process.wait
```

ここでの肝は、用意した１つのプロセスから並行処理のために複数の子プロセス生成して、
その後は子プロセスの面倒を見るという所
子プロセスたちが応答するのかを確かめたり、子プロセスが終了した際には、その後始末をしたりする

UniconrというWEBサーバはこのパターンを採用している

## １５章
非同期でタスクを処理するために「打ちっぱなし」で子プロセスを作成したが、今度は
ちゃんと子プロセスを始末するためのセクション

ゾンビプロセスは親プロセスに待たれずに死んでしまった子プロセス全てということ
なので、親プロセスが子プロセスを待っていない間に子プロセスが終了してしまったら、確実にゾンビになる
spawnlingというgemパッケージはプロセスやスレッドを扱う総称的なAPIを提供することに加えて
「打ちっぱなし」で生成した子プロセスをきちんとデタッチしてくれる

Process.waitは子プロセスが終了してから長時間経過しても取得することができる
カーネルは親プロセスがProcess.waitを使ってその情報を要求するまで、
終了した子プロセスの情報をずっと持ち続けてしまい、カーネルのリソースを無駄遣いしてしまう

子プロセスを待つつもりがないのなら、子プロセスをデタッチしなければならない

```ruby
mesage = 'Good Morning'
recipient = 'tree@mybackyard.com'

pid = fork do
  StatsCollector.record message, recipient
end

# pidを指定してデタッチする(ゾンビにならないようにする)
Process.detach(pid)
```

Process.detachは新しいスレッドを生成して、pidで支持された子プロセスの終了を待ち受ける
こうすることで、カーネルは誰からも必要とされない終了ステータスを待ち続けなくて良くなる

（孫プロセスを作ったり、本当にデタッチするわけではない）

```ruby
# 1病後に終了する子プロセスを生成
pid = fork { sleep 1 }
# 終了した子プロセスのpidを出力
puts pid
# 親プロセスのpidを出力
sleep 5
```

上記のようにすれば子プロセスのステータスを調査することが可能になりので、下記のコマンドで確認する（zかZ+になっているはず）


```bash
$ ps -ho pid,state -p [zombie-process-id]
```



