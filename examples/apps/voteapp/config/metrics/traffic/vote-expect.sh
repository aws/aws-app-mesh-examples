#!/usr/bin/expect -f
spawn ./vote.sh
expect "*What do you like better*"
#Represents up arrow selection. So will select the last option - Dogs
send "\033\[A"
send -- "\r"
interact
spawn ./vote.sh
expect "*What do you like better*"
#Represents down arrow selection. So will select the second option - Cats
send "\033\[B"
send -- "\r"
interact
spawn ./vote.sh
expect "*What do you like better*"
#Represents up arrow selection. So will select the first option - Dogs
send "\033\[A"
send -- "\r"
interact
