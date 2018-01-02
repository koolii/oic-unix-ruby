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


## １６章
親プロセスが忙しい時に子プロセスを扱うためのUnixシグナル

SIGCHLDのサンプルコード => `src/16/signal-chld.rb`

シグナルは信頼ができなく、CHLDシグナルを処理している最中に別の子プロセスが終了した場合
次のCHLDシグナルを補足できるかどうかはその保証がない

想定どおりにちゃんと動くこともあるが、子プロセスが終了したことを「見失う」こともある
CHLDを適切に扱うには、Process.waitの呼出しをループさせて、
子プロセスが死んだという通知を全て処理するまで待ち受ける必要がある

上記の対応はシグナルを処理している間に複数のCHLDシグナルを受信するかもしれない状況への対応だが、
子プロセスがない状態でProcess.waitをすると、例外がスローされる

そこでProcess.wait2を利用する、Process.wait2の第二引数にはフラグを渡すことができ、
終了を待つ子プロセスがなければブロックしないようカーネルに指示することが出来る

```ruby
Process.wait(-1, Process:WNOHANG)
```

`src/16/signal-chld.rb`をどの子プロセスの死も見失わないようにする => `src/16/signal-chld-improve.rb`

シグナルは非同期通信で、プロセスはカーネルからシグナルを受けた時、いずれかの処理を行う
1. シグナルを無視
2. 特定の処理
3. デフォルトの処理

シグナルはカーネルから送られるが、本当は別のプロセスから送られてくるもので、カーネルはその仲介役をしているに過ぎない
(これは当初、あるプロセスをどうやって強制終了すべきかを指定するためのものだったから)

別ターミナルで２つのrubyスクリプトを実行する(wait.rbでpidを確認してからkill.rbでプロセスを強制終了)
`src/16/wait.rb`
`src/16/interrupt.rb`

INT(interrupt)シグナルを使ってプロセスを中断し、強制終了させる
ただし、INTシグナルの振る舞いを上書きするとプロセスはどうなるか => `src/16/wait-block.rb`を実行後に、`src/16/interrupt.rb`でプロセスをkillしてみる
結果としてはkillされずにプロセスはそのままになる

それでもSIGKILLシグナルを使うと必ずプロセスをkillすることが出来る

```ruby
Process.kill(:KILL, <最初の ruby プロセスの pid>)
```

シグナルはグローバル変数を扱っているようなものなのでハンドリングなどには注意が必要で
同一のシグナルに対する実装が上書きされてしまわないようにする

SIGINTの実装をそのまま使った上で、独自の実装を加える => `src/16/covered-sigint.rb`
システム標準のSIGINT処理はシステムエラーになる => `src/16/confirm-if-covered-system-sigint.rb`


## １７章
複数のプロセス間で情報をやり取りするときには、IPCという分野の話となる
よく使われるのは、パイプとソケットの２つ

パイプは単方向へのデータの流れをいい、プロセスとプロセスをつなぐ事を言う
これにより、パイプを通じてデータを流すことができるが、双方向ではなく単方向のみをサポート

```ruby
reader, writer = IO.pipe #=> [#<IO:fd 5>, #IO<:fd 6>]
```
２つの要素を持つ配列を返し(reader,writer)、このIOクラスはFile/TCPSocket/UDPSocketクラス等の親となっていて、基本的にIOオブジェクトは名前のないファイルのように考えられる

パイプはリソースとみなすことができ、ファイルディスクリプタを始めとする
リソースとしての側面を備えていて、子プロセスとも共有される

親プロセスとこプロセス間の通信にパイプを使う => `src/17/pipe-parent.rb`

※ この書籍では、「ストリーム」を開始と終了の概念を持たずにパイプにデータの読み書きを行うという意味となる

通信にはストリームだけじゃなくメッセージも使うことができるがUnixソケットを使うことを余儀なくされる
Unixソケットは同一の物理マシン上だけで通信できるソケットの一種で、TCPソケットよりも遥かに早い

```ruby
require 'socket'
Socket.pair(:UNIX, :DGRAM, 0) #=> [#<Socket:fd 15>, #<Socket:fd 16>]
```

上記を使うことで互いが接続されたUnixソケットのペアを作成できる
作成されたソケットではストリームではなく、データグラムを使って通信する
(この場合、ソケットにはメッセージ全体を書き込み、別のソケットからはメッセージ全体を読み込むのでデリミタは必要ない)
また、パイプではなくソケットを使うと双方向のデータ通信が可能であることがわかる

同一マシン以外でIPCをするには少し考えなければならない
IPCは物理マシン上でのプロセス間通信が前提であるから
なので複数マシンで通信をするには。。。。
素直にTCPソケットを使う、他にはRPCやZeroMQのようなメッセージング／システム、
あるいはいわゆる分散システムを活用する方法がある

パイプもソケットもプロセス間通信を扱うためのもので早いし、簡単
共有データベースやログファイルの代わりに通信チャンネルとしてよく使われている

SpyglassプロジェクトのSpyglassMasterクラスを参考にすると、一つのパイプを通じて親プロセスと通信する具体例が示されている

## １８章 デーモン
デーモンプロセスはバックグラウンドで動作するプロセスで、サーバのようなリクエストを捌くために
バックグラウンドで常に動作するプロセスがあげられる
さまざまなデーモンプロセスがシステムを正常に動作することを支えている

OSにとって特別重要なデーモンプロセスがあり、それはinitプロセス
initプロセスのppidは0で「すべてのプロセスの始祖」、pidは1となる

rackを例とすると、rackupコマンドで起動し、さまざまなrack対応webサーバ上でアプリをホストする(プロセスをバックグラウンドで実行される箇所を見てみる)
Process.daemonを呼び出すだけでプロセスをデーモン化させられる

```ruby
def daemonize_app
  if RUBY_VERSION < "1.9"
    exit if fork
    Process.setsid
    exit if fork
    Dir.chdir "/"
    STDIN.reopen "/dev/null"
    STDOUT.reopen "/dev/null", "a"
    STDERR.reopen "/dev/null", "a"
  else
    Process.daemon
end end
```

forkメソッドは二度帰る
一度は親プロセス（子プロセスのpidが戻り値）、次に子プロセス（戻り値はない）
よって、上記の`exit if fork`は親プロセスは終了するが、
子プロセス＝孤児プロセスとなった子プロセスはそのまま継続する

孤児プロセスのProcess.ppidを呼び出すと常に1が帰る
このことからinitプロセスだけが常にアクティブであると期待できるということが分かる

Process.setsidは３つの処理を行う
* プロセスを新しいセッションのセッションリーダにする
* プロセスを新しいプロセスグループのプロセスグループリーダになる
* プロセスから制御端末を外す

この３つの処理を理解するためにプロセスグループとセッショングループについて解説する

18.5 プロセスグループとセッショングループ

プロセスグループとセッショングループはジョブ制御にまつわる考え方

すべてのプロセスはどこかしらのプロセスグループに属しており、各プロセスグループにはユニークな整数のIDが振られている
プロセスグループとは単に関連するプロセスが集まったものでしかなくて、`Process.setpgrp(new_group_id)`を使ってグループのIDを設定すれば、任意のプロセスをグループ化することも出来る

```ruby
puts Process.getpgrp
puts Process.pid
```

プロセスグループリーダーは、端末から入力したユーザコマンド等の「最初の」プロセスになる
つまり、irbを起動した場合、irbプロセスが新しいプロセスのグループのプロセスリーダーになるということになる
そして、そのプロセスから生成された子プロセスは全て、同じプロセスグループに属することになる

親プロセスが終了しても子プロセスは継続する、親プロセスが終了した場合の振る舞いはこうなのだが、
親プロセスが端末から制御されていて、シグナルによって終了させられた場合には、少し異 なった振る舞いをみせる

長時間動き続ける外部コマンドは孤児プロセスにならない、外部コマンドは、親プロセスが死ぬと継続しない
実は、端末はシグナルを受け取ると、フォアグラウンドのプロセスが属するプロセスグループに含まれるプロセスすべてにシグナルを転送するため同じシグナルで終了する

セッショングループは、プロセスグループよりも抽象度をもう一弾上げたもので、プロセスグループの集合を表す

```bash
git log | grep shipped | less
```

上記のようなコマンドは子プロセスを生成することになるが、コマンド間には親子関係はないので、コマンド毎に別々のプロセスグループが出来る
同じプロセスグループに属するコマンドは１つもないにも関わらず、Ctrl-Cで一発終了させることができるが、これはコマンドは同じセッショングループに属しているから
セッショングループもプロセスグループの時に続いて、端末はセッションリーダーにシグナルを送ると、そのセッションに属する全てのプロセスグループにシグナルが転送される


Rackに戻り、
最初の行は、子プロセスが生成されて親プロセスが終了している、プロセスを起動した端末は、コマンドが終了したと認識するので、
端末の制御をユーザに戻す
ところが、生成された子プロセスは親から引き継いだグループIDとセッションIDを持ったままなので、
生成された子プロセスはセッションリーダでもなければプロセスグループリーダでもない
端末自体は子プロセスへの接続を持ったままなので、端末からセッショングループへシグナルが送られると、生成された子プロセスにもシグナルが転送されてきてしまう
その回避策として、Process.setsidをを使って、生成された子プロセスを端末から完全に切り離す

これにより、生成された子プロセスを新しく生成したプロセスグループとセッショングループのリーダにすることができる
（ただし、プロセスがすでにプロセスグループリーダの場合は、Process.setsidが失敗する）


```ruby
exit if fork
```

生成された子プロセスはそれぞれのリーダになったが、再びfork(2)して終了する
さらに生成されたプロセスはプロセスグループリーダでもなければセッションリーダでもない
このプロセスは制御端末を持たないことが保証される(親プロセスが孫プロセスまで接続はしないと言う考え方でよい？)
これによりプロセスが制御端末から完全に分離され、デーモンとして動作するようになる


```ruby
Dir.chdir "/"
```

実行ディレクトリをルートに移動させて、おけば、デーモンの実行中に作業ディレクトリが消えなくなる
実行ディレクトリが何らかの理由で削除されてしまったり、アンマウントされてしまった場合に起こる問題を回避できる

```ruby
STDIN.reopen "/dev/null"
STDOUT.reopen "/dev/null", "a"
STDERR.reopen "/dev/null", "a"
```

全ての標準ストリームを`/dev/null`に送るように設定
デーモンは標準ストリームが使えないのだが、プログラム上で標準ストリームが利用可能なことを想定して実装されていることがあるので、
プログラム上では、標準ストリームが使えるように見せかけるために`/dev/null`にリダイレクトさせている
