from argparse import ArgumentParser
from requests import get, post
from json import dumps

API_HOST = "https://api.kilterboardapp.com"

def getListOfGyms():
	res = get(API_HOST + "/v1/pins?types=gym")
	if not res.ok:
		print("Something went wrong. Please try again.")
	else:
		print(dumps(res.json(), indent=2))

def printListOfWalls(walls):
	for wall in walls:
		print("Name: " + wall["name"])
		print("Serial Number: " + wall["serial_number"])
		print("Adjustable: " + str(wall["is_adjustable"]))
		print("Product ID: " + str(wall["product_id"]))
		print("Product Size ID: " + str(wall["product_size_id"]))
		print("Layout ID: " + str(wall["layout_id"]))
		print("Set ID's: " + ", ".join(map(str, wall["set_ids"])))
		print()

def getBoardDetails(boardID, username, password):
	res = post(API_HOST + "/v1/logins", json={"username": username, "password": password})
	if not res.ok:
		print("Something went wrong while logging in. Maybe your details are incorrect?")
		return
	token = res.json()["token"]
	
	res = get(f"{API_HOST}/v2/users/{boardID}", headers={"authorization": f"Bearer {token}"})
	if not res.ok:
		print("Something went wrong. Please try again.")
	else:
		dataObj = res.json()["user"]
		if dataObj["name"] == None or dataObj["walls"] == None:
			print(f"ID {boardID} does not appear to have a gym associated with it.")
		else:
			print("Walls for " + res.json()["user"]["name"] + ":\n--------------------------------------------------------")
			printListOfWalls(res.json()["user"]["walls"])

def main(args):
	if args.get_gyms == True:
		getListOfGyms()		
	elif args.id == None:
		print("ERROR: -i parameter required")
		return
	elif args.username == None:
		print("ERROR: -u parameter required")
		return
	elif args.password == None:
		print("ERROR: -p parameter required")
		return
	else:
		getBoardDetails(args.id, args.username, args.password)

if __name__ == "__main__":
	argParser = ArgumentParser(description="Retrieves kilter board details from the kilter board API.", allow_abbrev=False)
	argParser.add_argument("-g", "--get-gyms", help="If this argument is present, instead of grabbing details for a specific board, this script will get a list of gyms.", action="store_true")
	argParser.add_argument("-i", "--id", help="id of the gym to grab boards for. This can be found by looking at the gym list - see the '-g' option.", type=int)
	argParser.add_argument("-u", "--username", help="Username of a kilter board account. Needed because this part of the API requires authorization for some reason.", type=str)
	argParser.add_argument("-p", "--password", help="Password of a kilter board account. Needed because this part of the API requires authorization for some reason.", type=str)
	main(argParser.parse_args())