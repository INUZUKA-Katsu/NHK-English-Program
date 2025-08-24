path="/Users/inuzuka0601/Dropbox/☆英語学習/NHK英会話/英会話/2025/"


files = Dir.glob(path+"*")
files.delete_if{|f| f.match(/-\d\.mp3/)}

クリップ = files.select do |f|
  f.match(/英会話ダイアログ/)
end.map do |f|
  num=File.basename(f).match(/\d+/)[0]
  [num.to_i,f]
end.to_h

放送原本 = files.select do |f|
  f.match(/英会話ハートでつかめ!英語の極意/)
end.map do |f|
  num=File.basename(f).match(/\d+/)[0]
  [num.to_i,f]
end.to_h

ary=[]
放送原本.size.times do |i|
  path1 =放送原本[i+1]
  if クリップ[i+1]
    fname2=File.basename(クリップ[i+1]).sub(/\.(mp3|m4a)/,"")
    path2 =クリップ[i+1]
    ary<<"*[[#{fname2}|#{path2}]]（[[放送全体|#{path1}]]）"
  else
    kai=File.basename(path1).match(/\d+/)[0]
    ary<<"*英会話ダイアログ#{kai}（[[放送全体|#{path1}]]）"
  end 
end

sp="!!夏休みスペシャル\n*[[英会話英語のお悩み解決!夏休みスペシャル|/Users/inuzuka0601/Dropbox/☆英語学習/NHK英会話/英会話/英会話英語のお悩み解決!夏休みスペシャル.mp3]]\n"

str=""
month=3
ary.each_with_index do |s,i|
  if i % 20 ==0
    month+=1
    month=month-12 if month>12
    if month==8
      str = str + sp
    end
    str = str + "!!#{month}月号\n"
  end
  str = str + s + "\n"
end

puts str