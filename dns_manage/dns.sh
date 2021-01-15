### 在172.16.114.55 上执行

#python ./dnschange.py -K 4072f7fc0e2ad9c35fd94919 -A change -d fp2.pub.sina.com.cn -t  10.73.231.186 -f 10.73.231.182


curl -sSL -H 'accept: application/json' -XPOST -d "key=4072f7fc0e2ad9c35fd94919&change[0][domain]=fp2.pub.sina.com.cn&change[0][from]=10.73.231.186&change[0][to]=10.73.231.182" http://dnschange.intra.sina.com.cn/api | jq .

curl -sSL -H 'accept: application/json' -XPOST -d "key=4072f7fc0e2ad9c35fd94919&change[0][domain]=fp2.pub.sina.com.cn&change[0][from]=10.73.231.182&change[0][to]=10.73.231.186" http://dnschange.intra.sina.com.cn/api | jq .