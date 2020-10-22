#  Todo File

1) Initiate location tracking on app startup if sending chats exist in core data :white_check_mark:
2) Recreate location subscription when app started with background request (https://github.com/malcommac/SwiftLocation#background_monitoring) :white_check_mark:
3) Allow alternative backend servers :white_check_mark: 
4) Change to full usernames when sending, don't recreate assuming server name :white_check_mark: 
5) Delete keys locally when used in a received pre-key message  :white_check_mark: 
6) Fix occasional failure to load OLM account data from KeyChain and subsequent deletion of all data :white_check_mark:
7) When loading from keychain does fail delete stored chats as well :white_check_mark:
8) Fix 'Failed to Send Message' error. :white_check_mark:
9) When Stop Transmission clicked in Chat screen only delete chat if not also receiving :white_check_mark:
10) Create method to delete chat :white_check_mark:
11) Handle no prekeys available remotely :white_check_mark: 
12) Ensure device deleted on server when logging out :white_check_mark: 
13) Fix appearance of navbar items on content screen :white_check_mark: 
14) Improve error descriptions :white_check_mark: 
15) Handle upoad new prekeys when running low :white_check_mark: 
16) Perform sync on loading content and chat pages :white_check_mark: 
17) Animate sync icon :white_check_mark: 
18) Handle preservation of user data on logout :white_check_mark: 
19) Fix timeout on sync :white_check_mark: 
22) Fix hidden text on chat screen in dark mode :white_check_mark: 
23) Centre map on pin on page load :white_check_mark: 
24) Fix fail on alternate syncs :white_check_mark: 
25) Prevent infinite loop in newLocationReceived :white_check_mark: 
26) Send locaiton update immediately on new chat creation to check user/device name etc :white_check_mark: 
27) Fix chat from same user different device doesn't appear as new device. :white_check_mark: 
28) Add text to login page clarifying exact login address :white_check_mark: 
29) Set zoom level for intial map :white_check_mark: 
30) Fix allow multiple openings of set server dialog :white_check_mark: 
31) Fix location pin only shows once :white_check_mark: 
32) Fix location pin doesn't update :white_check_mark: 
33) Fix doesn't stop location tracking when deleting last transmitting chat :white_check_mark:
34) Allow dismissal of altered chat alert


Note:

To ensure toDevice messages go through update 'since' when syncing.

Note: 

Iphone connecting and disconnecting? Use `sudo killall -STOP -c usbd`

