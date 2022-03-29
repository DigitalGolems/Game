// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../Utils/SafeMath.sol";
import "../Utils/Owner.sol";
import "./Interfaces/IAsset.sol";

contract Assets is Owner, IAsset {

    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    struct Asset {
        uint8 kind;     //Human - 0
                        //Amphibian - 1
                        //Insectoid - 2
                        //Bird - 3
                        //Animal - 4
        uint32 layer;
        uint16 part;
        uint8 rarityLevel;
        //parts //СКОРЕЕ ВСЕГО ЗОЛОТЫЕ И ЭЛЕМЕНТАЛЬНЫЕ К ДРУГОЙ ПЕРЕМЕННОЙ
        //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //armor id - 5
        //gold inclusions id -6
        //additional limbs from the chest id - 7
        //accessories on the head id -8
        //wings id - 9
        //eyes id - 10
        //mask id - 11
        //nimbus id - 12
        //base model elements basis id - 13
        //base model elements hands id - 14
        //base model elements legs id - 15
        //base model elements head id - 16
        //base model elements background id -17
        //wings elements id - 18
        //base model gold basis id - 19
        //base model gold hands id - 20
        //base model gold legs id - 21
        //base model gold head id - 22
        //base model gold background id -23
        //gold armor id - 24
        //additional gold limbs from the chest id - 25
        //gold accessories on the head id -26
        //gold wings id - 27
        //gold eyes id - 28
        //gold mask id - 29
        //gold nimbus id - 30
    }

    //this Struct needs just for sending to frontend
    //because we cant send mapping
    struct AssetToSend{
        uint8 kind;
        uint32 layer;
        uint16 part;
        uint8 rarityLevel;
    }

    address public gameAddress;
    address public labAddress;
    address public psychoAddress;

    Asset[] public assets;
    mapping(uint256 => mapping(address => uint32)) assetOwners;//counts amount of this asset to owner
    mapping(address => uint32) public ownerAssetCount;
    mapping(address => mapping(address => mapping(uint32 => bool))) private _allowances; //asset owner address => address who approved => asset ID => true/false

    function setGame(address _game) public isOwner {
        gameAddress = _game;
    }

    function setLab(address _lab) public isOwner {
        labAddress = _lab;
    }

    function setPsycho(address _psycho) public isOwner {
        psychoAddress = _psycho;
    }

    function getAllAssetsCount() public view returns(uint256) {
        return assets.length;
    }

    //adding assets by owner
    function addAssetByOwner(
        uint8 kind,
        uint32 layer,
        uint16 part,
        uint8 rarity
    ) public isOwner {
        //pushing new asset to assets array
        Asset storage newAsset = assets.push();
        //write data to new asset
        newAsset.kind = kind;
        newAsset.layer = layer;
        newAsset.part = part;
        newAsset.rarityLevel = rarity;
    }

    function addAssetByOwnerMultiple(
        uint8[] memory kinds,
        uint32[] memory layers,
        uint16[] memory parts,
        uint8[] memory rarities
    ) public isOwner {
        for (uint16 i = 0; i < kinds.length; i++) {
            //pushing new asset to assets array
            Asset storage newAsset = assets.push();
            //write data to new asset
            newAsset.kind = kinds[i];
            newAsset.layer = layers[i];
            newAsset.part = parts[i];
            newAsset.rarityLevel = rarities[i];
        }
    }

    //adding user to assets
    function addUserToAssetOwner(uint32 ID, address _to) public isOwner {
        //add
        assetOwners[ID][_to] = assetOwners[ID][_to].add(1);
        //user assets count +1
        ownerAssetCount[_to] = ownerAssetCount[_to].add(1);
    }

    //deleting user from assets
    function deleteUserFromAssetOwner(uint32 ID, address _from) public isOwner {
        //delete
        assetOwners[ID][_from] = assetOwners[ID][_from].sub(1);
        //user assets count -1
        ownerAssetCount[_from] = ownerAssetCount[_from].sub(1);
    }

    //FOR Psychospheres Loot
    //adding user to assets
    function addUserToAsset(uint32 ID, address _to) public onlyLabOrPsycho {
        //add
        assetOwners[ID][_to] = assetOwners[ID][_to].add(1);
        //user assets count +1
        ownerAssetCount[_to] = ownerAssetCount[_to].add(1);
    }

    function addUserToAssetThis(uint32 ID, address _to) private {
        //add
        assetOwners[ID][_to] = assetOwners[ID][_to].add(1);
        //user assets count +1
        ownerAssetCount[_to] = ownerAssetCount[_to].add(1);
    }

    //FOR Lab combining
    //deleting user from assets
    function deleteUserFromAsset(uint32 ID, address _from) public onlyLabOrPsycho {
        //delete
        assetOwners[ID][_from] = assetOwners[ID][_from].sub(1);
        //user assets count -1
        ownerAssetCount[_from] = ownerAssetCount[_from].sub(1);
    }

    function deleteUserFromAssetThis(uint32 ID, address _from) private {
        //delete
        assetOwners[ID][_from] = assetOwners[ID][_from].sub(1);
        //user assets count -1
        ownerAssetCount[_from] = ownerAssetCount[_from].sub(1);
    }

    //FOR DUEL
    //losing every second asset after 0 including
    //means if user has 0,1,2,3,4 assets he would lose 1,3
    function loseAssets(address _winner, address _loser) public onlyGame {
        //if user has assets
        if (ownerAssetCount[_loser] > 1) {
            //getting all losers assets IDs
            uint32[] memory loserAssets = getAllUserAssets(_loser);
            //starting cycle for loserAssets array
            for (uint32 i = 0; i < ownerAssetCount[_loser]; i++) {
                //checks odd num
                if (i % 2 == 1) {
                    //if odd
                    //add to winner
                    addUserToAssetThis(loserAssets[i], _winner);
                    //delete from loser
                    deleteUserFromAssetThis(loserAssets[i], _loser);
                }
            }
        }
    }

    //Getting owner assets count
    function getOwnerAssetCount(address _owner) public view returns (uint32) {
        return ownerAssetCount[_owner];
    }

    //Get all user assets IDs
    function getAllUserAssets(address _owner) public view returns(uint32[] memory) {
        //creating array with length of owner assets count
        uint32[] memory result = new uint32[](ownerAssetCount[_owner]);
        uint32 counter = 0;
        //for all assets array
        for (uint32 i = 0; i < assets.length; i++) {
            //chechs if owner written to asset
            if (assetOwners[i][_owner] >= 1) {
                //create new cycle for one asset
                //because user can has few copies of one asset
                for (uint32 j = i; j < i + assetOwners[i][_owner]; j++) {
                    //writing id in assets array
                    result[counter] = i;
                    counter++;
                }
            }
        }
        return result;
    }

    //Get one asset by ID it assets array
    function getAsset(uint256 ID) public view returns(Asset memory) {
        return assets[ID];
    }

    //get just one part of asset for lab combining
    function getAssetPart(uint32 ID) public view returns(uint16 _part) {
        _part = assets[ID].part;
    }

    //get user amount of one asset
    function assetToOwner(address user, uint256 ID) public view returns (uint32) {
        return assetOwners[ID][user];
    }

    //get amount of all assets
    function getAssetsAmount() public view isOwner returns(uint256){
        return assets.length;
    }

    //checks if user has asset
    function getIsUserAsset(address user, uint256 ID) public view returns(bool){
        return assetOwners[ID][user] >= 1 ? true : false;
    }

    //get allowance of using assets
    //mostly all next functions needs for market
    function allowance(address owner, address spender, uint32 ID) public view virtual returns (bool) {
        return _allowances[owner][spender][ID];
    }

    //public approve asset
    function approveAsset(address spender, uint32 ID) public returns (bool) {
        //checks if user has asset
        require(getIsUserAsset(msg.sender, ID) == true, "Not yours asset");
        //private approve
        _approveAsset(msg.sender, spender, ID);
        return true;
    }

    //public transfer asset
    function transferAsset(address to, uint32 ID) public {
        //cant transfer to zero address
        require(to != address(0));
        //checks if user really has this asset
        require(getIsUserAsset(msg.sender, ID) == true);
        //private transfer function
        _transferAsset(msg.sender, to, ID);
    }

    //transfer asset enable to transfer asset from approved address
    //mostly using in market
    function transferAssetFrom(address from, address to, uint32 ID) public {
        require(to != address(0));
        //checks allowance
        bool currentAllowance = _allowances[from][msg.sender][ID];
        require(currentAllowance == true, "You dont have allowance");
        _transferAsset(from, to, ID);
    }

    //private transfer function
    function _transferAsset(address _from, address _to, uint32 _ID) private {
        //delete asset from asset owner
        assetOwners[_ID][_from] = assetOwners[_ID][_from].sub(1);
        //add asset to asset recipient
        assetOwners[_ID][_to] = assetOwners[_ID][_to].add(1);
        //counting owner -1
        ownerAssetCount[_from] = ownerAssetCount[_from].sub(1);
        //counting recipient +1
        ownerAssetCount[_to] = ownerAssetCount[_to].add(1);
        //delete approve
        _deleteApprove(_from, _to, _ID);
        emit TransferAsset(_from, _to, _ID);
    }

    //approve private address
    function _approveAsset(
        address owner,
        address spender,
        uint32 ID
    ) private {
        //checkes if not zero addresses
        require(owner != address(0), "Assets: approve from the zero address");
        require(spender != address(0), "Assets: approve to the zero address");
        //adding allowance to asset
        _allowances[owner][spender][ID] = true;
        emit ApprovalAsset(owner, spender, ID);
    }

    //delete approve private function
    function _deleteApprove(
        address owner,
        address spender,
        uint32 ID
    ) private {
        //checkes if not zero addresses
        require(owner != address(0), "Assets: approve from the zero address");
        require(spender != address(0), "Assets: approve to the zero address");
        //delete allowance
        _allowances[owner][spender][ID] = false;
    }

    //only game contract can send to this function
    modifier onlyGame() {
        require((gameAddress != address(0)) || (msg.sender == gameAddress), "Only Game");
        _;
    }

    //only lab of psychopreheres contract can send to this function
    modifier onlyLabOrPsycho() {
        require(
            (msg.sender == labAddress)
            ||
            (msg.sender == psychoAddress)
            , "Only Lab or Psycho");
        _;
    }

}
