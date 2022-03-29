// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../../Utils/SafeMath.sol";
import "../../Utils/Owner.sol";
import "../Interfaces/IInventory.sol";
import "../Rent/IRent.sol";
import "../../Digibytes/Interfaces/IBEP20.sol";
import "../../DigitalGolems/Interfaces/ICard.sol";
import "../Interfaces/IPsychospheres.sol";
import "../Interfaces/IAsset.sol";

contract Session is Owner{
    using SafeMath for uint;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    //changing price isOwner
    uint256 pricePayoff = 10 * 10**18;
    IBEP20 public DBT;
    IPsychospheres public psychospheres;
    ICard public card;
    IInventory public inventory;
    IAsset public assets;
    IRent public rent;
    //counts card wins
    mapping (uint256 => uint32) public cardIDToWin;
    //counts card loses
    mapping (uint256 => uint32) public cardIDToLose;
    //counts user wins
    mapping (address => uint32) public userToWin;
    //counts user loses
    mapping (address => uint32) public userToLose;
    //checks if user payoffed to winner
    mapping (address => bool) private userPayoff;
    mapping (address => uint256) private userPayoffAmount;

    event FightingResult(address winner, uint256 winnerCard, address loser, uint256 loserCard, bool payoff);

    //setting addresses to contracts
    function setDBT(address _DBT) public isOwner {
        DBT = IBEP20(_DBT);
    }

    function setInventory(address _inventory) public isOwner {
        inventory = IInventory(_inventory);
    }

    function setAssets(address _assets) public isOwner {
        assets = IAsset(_assets);
    }

    function setPsycho(address _psycho) public isOwner {
        psychospheres = IPsychospheres(_psycho);
    }

    function setRent(address _rent) public isOwner {
        rent = IRent(_rent);
    }

    function setCard(address _card) public isOwner {
        card = ICard(_card);
    }

    //calls if winner didnt called his function
    function PVPResultOwner(
        address winner,
        uint256 winnerCard,
        address loser,
        uint256 loserCard
    ) public isOwner isUserCard(winnerCard, winner) isUserCard(loserCard, loser){
        if (userPayoff[loser] != true) {
            _recordResult(winner, winnerCard, loser, loserCard);
            _takeAssets(winner, loser);
            _takeSomeFromInventory(winner, loser, winnerCard, loserCard);
            emit FightingResult(winner, winnerCard, loser, loserCard, false);
        } else {
            _recordResult(winner, winnerCard, loser, loserCard);
            DBT.transfer(winner, userPayoffAmount[loser]);
            userPayoff[loser] = false;
            userPayoffAmount[loser] = userPayoffAmount[loser] - pricePayoff;
            emit FightingResult(winner, winnerCard, loser, loserCard, true);
        }
    }

    function _recordResult(address _winner, uint256 _winnerCard, address _loser, uint256 _loserCard) private {
        cardIDToWin[_winnerCard] = cardIDToWin[_winnerCard].add(1);
        cardIDToLose[_loserCard] = cardIDToLose[_loserCard].add(1);
        userToWin[_winner] = userToWin[_winner].add(1);
        userToLose[_loser] = userToLose[_loser].add(1);
    }

    function _takeAssets(address _winner, address _loser) private {
        if (assets.getOwnerAssetCount(_loser) != 0) {
            assets.loseAssets(_winner, _loser);
        }
    }

    function _takeSomeFromInventory(address _winner, address _loser, uint256 _winnerCard, uint256 _loserCard) private {
        inventory.loseFromInventory(
            _winner,
            _loser,
            cardIDToWin[_winnerCard],
            cardIDToLose[_loserCard],
            userToWin[_winner],
            userToLose[_loser]
            );
    }

    //for session
    //decrease each abilitity on one
    function decreaseAbility(uint256 _ID) private {
        card.decreaseNumAbilityAfterSession(_ID);
    }

    //loser can payoff duel
    function payoff() public {
        DBT.transferFrom(msg.sender, address(this), pricePayoff);
        userPayoffAmount[msg.sender] = userPayoffAmount[msg.sender] + pricePayoff;
        userPayoff[msg.sender] = true;
    }

    function changePayoffPrice(uint256 newPrice) public isOwner {
        pricePayoff = newPrice;
    }

    function getUserPayoff(address user) public view returns(bool _payoff, uint256 _amount) {
        _payoff = userPayoff[user];
        _amount = userPayoffAmount[user];
    }

    function getCardIDToWin(uint256 ID) public view returns(uint32) {
        return cardIDToWin[ID];
    }

    function getCardIDToLose(uint256 ID) public view returns(uint32) {
        return cardIDToLose[ID];
    }

    function getUserToWin(address user) public view returns(uint32) {
        return userToWin[user];
    }

    function getUserToLose(address user) public view returns(uint32) {
        return userToLose[user];
    }

    //writing session result with changing amounts of all
    function sessionResult(//как то регулировать тут все
        uint32[] memory things,
        uint32[] memory resources,
        uint32[] memory augmentations,
        uint8[] memory psychoAmount, //array because we have diffrent soil, so each ID means soil
        uint256 cardID,
        address user
    ) external isOwner isUserCard(cardID, user) {
        inventory.addThings(
            things,
            user
        );
        inventory.addResources(
            resources,
            user
        );
        inventory.addAugmentations(
            augmentations,
            user
        );
        psychospheres.addPsychosphere(user, psychoAmount);
        decreaseAbility(cardID);
    }

    function sessionDecreaseAbility(uint256 cardID, address player) external isOwner isUserCard(cardID, player) {
        decreaseAbility(cardID);
    }

    function sessionPsychospheresResult(
        uint8 amount,
        uint32 soil,
        address user
    ) external isOwner {
        psychospheres.addOnePsychosphere(user, soil, amount);
    }

    function sessionThingsResult(
        uint16 ID,
        uint16 amount,
        address user
    ) external isOwner {
        inventory.changeAmountOfOneThing(
            ID,
            amount,
            user
        );
    }
    function sessionResourcesResult(
        uint16 ID,
        uint16 amount,
        address user
    ) external isOwner {
        inventory.changeAmountOfOneResource(
            ID,
            amount,
            user
        );
    }
    function sessionAugmentResult(
        uint16 ID,
        uint16 amount,
        address user
    ) external isOwner {
        inventory.changeAmountOfOneAugmentation(
            ID,
            amount,
            user
        );
    }

    modifier isUserCard(uint256 id, address player) {
      bool cardRentExist;
      uint256 cardItemID;
      (cardItemID, cardRentExist) = rent.getItemIDByCardID(id);
      if (cardRentExist) {
          require(rent.getUserRenter(cardItemID) == player, "Not user card");
      } else {
          require(card.cardOwner(id) == player, "Not user card");
      }
      _;
    }

}
