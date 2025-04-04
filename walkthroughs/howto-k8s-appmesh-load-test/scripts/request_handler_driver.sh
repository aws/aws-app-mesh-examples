echo "Entered handler"
# sleep 600
# Install dependencies
pip3 install flask
echo "Completed flask"
pip3 install aiohttp
echo "Completed aiohttp"
pip3 install asyncio
echo "Completed asyncio"

# # Run flask server
flask run -p 9080
