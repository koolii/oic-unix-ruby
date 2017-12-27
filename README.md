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
