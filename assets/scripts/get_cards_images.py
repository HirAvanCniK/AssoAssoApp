import requests

BASE_URL = "https://www.deckofcardsapi.com"

deck_id = requests.get(BASE_URL+"/api/deck/new").json()['deck_id']

cards = requests.get(BASE_URL+f"/api/deck/{deck_id}/draw", params={'count': 52}).json()['cards']

for card in cards:
    open("../images/cards/"+card['code']+".png", "wb").write(requests.get(card['image']).content)

print("Got cards successfully!")