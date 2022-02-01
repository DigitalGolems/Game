// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../../Utils/SafeMath.sol";
import "../../Utils/Owner.sol";
import "../Inventory/Inventory.sol";
import "../Assets.sol";
import "./Access.sol";
import "../Rent/Rent.sol";
import "../../Digibytes/Digibytes.sol";
import "../../DigitalGolems/DigitalGolems.sol";
import "../Psychospheres.sol";

contract Session is Access {
    using SafeMath for uint;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    //changing price isOwner
    uint256 pricePayoff = 10 * 10**18;
    Digibytes public DBT;
    Psychospheres public psychospheres;
    DigitalGolems public DIG;
    Inventory public inventory;
    Assets public assets;
    Rent public rent;
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
    
    event FightingResult(address winner, uint256 winnerCard, address loser, uint256 loserCard);
    
    //setting addresses to contracts
    function setDBT(address _DBT) public isOwner {
        DBT = Digibytes(_DBT);
    }

    function setDIG(address _DIG) public isOwner {
        DIG = DigitalGolems(_DIG);
    }

    function setInventory(address _inventory) public isOwner {
        inventory = Inventory(_inventory);
    }

    function setAssets(address _assets) public isOwner {
        assets = Assets(_assets);
    }

    function setPsycho(address _psycho) public isOwner {
        psychospheres = Psychospheres(_psycho);
    }

    function setRent(address _rent) public isOwner {
        rent = Rent(_rent);
    }

    //validation is here because we want only winner to use this func
    //also winner cant use this function multiple times after using
    //because we sign with amount of user wins that increase after writing result
    function PVPResultWinner(
        address winner, 
        uint256 winnerCard, 
        address loser, 
        uint256 loserCard,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s
    ) 
    public 
    onlyValidResult(_v, _r, _s, uint256(userToWin[winner]))
    {
        require(
            (DIG.ownerOf(winnerCard) == winner)
            ||
            (rent.getUserRenter(rent.getItemIDByCardID(winnerCard)) == msg.sender),
            "Not winner card");
        require(
            (DIG.ownerOf(loserCard) == loser)
            ||
            (rent.getUserRenter(rent.getItemIDByCardID(loserCard)) == msg.sender),
            "Not loser card");
        if (userPayoff[loser] != true) {
            _recordResult(winner, winnerCard, loser, loserCard);
            _takeAssets(winner, loser);
            _takeSomeFromInventory(winner, loser, winnerCard, loserCard);
        } else {
            _recordResult(winner, winnerCard, loser, loserCard);
            userPayoff[loser] = false;
        }
        emit FightingResult(winner, winnerCard, loser, loserCard);
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
        DIG.decreaseNumAbilityAfterSession(_ID);
    }

    //loser can payoff duel
    function payoff(address whoPays) public {
        require(DBT.balanceOf(whoPays) >= pricePayoff, "Not enough DBT");
        require(DBT.allowance(whoPays, address(this)) >= pricePayoff, "Not allowance DBT");
        userPayoff[whoPays] = true;
        DBT.transferFrom(whoPays, address(this), pricePayoff);
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
    ) external{
        require(
            (DIG.ownerOf(cardID) == user)
            ||
            (rent.getUserRenter(rent.getItemIDByCardID(cardID)) == user),
            "Not yours card");
        require(things.length >= 5, "Need more Things");
        require(resources.length >= 4, "Need more Resources");
        require(augmentations.length >= 9, "Need more Augmentations");
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

}