// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../Utils/SafeMath.sol";
import "../Utils/Owner.sol";
import "./Interfaces/IAsset.sol";
import "./Interfaces/IPsychospheres.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


contract Psychospheres is IPsychospheres, Owner, VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    using SafeMath for uint;
    using SafeMath32 for uint32;

    struct Psychosphere {
        bool opened;
        bool looted;
    }

    address public game;
    IAsset public assetsContract;
    address public lab;

    uint256 psychoAmountToCombine = 4;

    Psychosphere[] psychospheres;
    mapping (uint256 => address) psychosphereToOwner;
    mapping (uint256 => uint32) psychosphereToAsset;
    mapping (bytes32 => uint256) requestIDToPsycho;
    mapping (address => mapping(uint32 => uint256)) ownerToSubstrate; //100 - one substrat, 25 - 1/4 substrat
                                                                      //uint32 means type of soil
    mapping (address => uint32) ownerPsychospheresCount;
    mapping(address => mapping(address => mapping(uint256 => bool))) private _allowances;

    constructor ()
        VRFConsumerBase(
            0xa555fC018435bef5A13C6c6870a9d4C11DEC329C, // VRF Coordinator
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06  // LINK Token
        )
    {
        keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186; //BST TEST
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network) //BST TEST
    }

    function setGameContract(address _game) public isOwner {
        game = _game;
    }

    function setAssetsContract(address _assetsContract) public isOwner {
        assetsContract = IAsset(_assetsContract);
    }

    function setLabContract(address _lab) public isOwner {
        lab = _lab;
    }

    function setPsychoAmountToCombine(uint256 _amount) public isOwner {
        psychoAmountToCombine = _amount;
    }

    //add after session
    function addPsychosphere(address to, uint8[] memory amount) public onlyGame {
        //take one type of psycho
        for (uint8 i = 0; i < amount.length; i++) {
            //count amount of this type
            for (uint8 j = 0; j < amount[i]; j++){
                //adding this type
                uint256 id = psychospheres.length;
                psychospheres.push(
                    Psychosphere(
                        false,
                        false
                    )
                );
                psychosphereToOwner[id] = to;
                ownerToSubstrate[to][i] = ownerToSubstrate[to][i].add(25);
                ownerPsychospheresCount[to] = ownerPsychospheresCount[to].add(1);
                emit AddPsychospheres(to, 1, i);
            }
        }
    }

    function addOnePsychosphere(address to, uint32 soil, uint8 amount) public onlyGame {
        for (uint8 i = 0; i < amount; i++) {
            uint256 id = psychospheres.length;
            psychospheres.push(
                Psychosphere(
                    false,
                    false
                )
            );
            psychosphereToOwner[id] = to;
            ownerToSubstrate[to][soil] = ownerToSubstrate[to][soil].add(25);
            ownerPsychospheresCount[to] = ownerPsychospheresCount[to].add(1);
        }
        emit AddPsychospheres(to, amount, soil);
    }

    function decreaseSubstrate(address who, uint32 _soil) public onlyLab {
        ownerToSubstrate[who][_soil] = ownerToSubstrate[who][_soil].sub(400);
    }

    function getSubstrate(address who, uint32 _soil) public view returns(uint256) {
        return ownerToSubstrate[who][_soil];
    }

    function checkHasEnoughOneTypeOfSubstrate(address who, uint32 _soil) public view returns(bool) {
        return ownerToSubstrate[who][_soil] >= 400;
    }

    //FOR TESTING
    function addPsychosphereByOwner(address to, uint8 amount, uint32 _soil) public isOwner {
        for (uint8 i = 0; i < amount; i++) {
            uint256 id = psychospheres.length;
            psychospheres.push(
                Psychosphere(
                    false,
                    false
                )
            );
            psychosphereToOwner[id] = to;
            ownerToSubstrate[to][_soil] = ownerToSubstrate[to][_soil].add(25);
            ownerPsychospheresCount[to] = ownerPsychospheresCount[to].add(1);
        }
        emit AddPsychospheres(to, amount, _soil);
    }

    //adding random asset
    function lootPsychosphereAsset(uint256 _id) public assetsContractIsSet {
        require(psychosphereToOwner[_id] == msg.sender, "Only owner of psycho");
        if (psychospheres[_id].opened = true) {
            assetsContract.addUserToAsset(psychosphereToAsset[_id], msg.sender);
            psychospheres[_id].looted = true;
            ownerPsychospheresCount[msg.sender] = ownerPsychospheresCount[msg.sender].sub(1);
            psychosphereToOwner[_id] = address(0);
            emit LootPsychosphereAsset(msg.sender, _id);
        } else {
            //СДЕЛАТЬ ОРАКУЛ
            uint32 _asset = uint32(uint256(keccak256(abi.encodePacked(block.timestamp))) % assetsContract.getAllAssetsCount());
            psychosphereToAsset[_id] = _asset;
            assetsContract.addUserToAsset(psychosphereToAsset[_id], msg.sender);
            psychospheres[_id].opened = true;
            psychospheres[_id].looted = true;
            ownerPsychospheresCount[msg.sender] = ownerPsychospheresCount[msg.sender].sub(1);
            psychosphereToOwner[_id] = address(0);
            emit LootPsychosphereAsset(msg.sender, _id);
        }
    }

    //seeing what asset here
    function openPsychosphere(uint256 _id) public {
        require(psychosphereToOwner[_id] == msg.sender, "Only owner of psycho");
        addRandomAssetToPsycho(_id);
    }

    function addRandomAssetToPsycho(uint256 _id) private {
        // require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK"); //CHAINLINK
        // requestIDToPsycho[requestRandomness(keyHash, fee)] = _id; //CHAINLINK
        //TEST
        uint256 _rand = uint256(keccak256(abi.encodePacked(block.timestamp)));
        fulfillRandomnessTEST(_id, _rand);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        psychospheres[requestIDToPsycho[requestId]].opened = true;
        psychosphereToAsset[requestIDToPsycho[requestId]] = uint32(randomness % assetsContract.getAllAssetsCount());
        emit OpenPsychosphere(msg.sender, requestIDToPsycho[requestId]);
    }

    function fulfillRandomnessTEST(uint256 _id, uint256 randomness) internal {
        psychospheres[_id].opened = true;
        psychosphereToAsset[_id] = uint32(randomness % assetsContract.getAllAssetsCount());
        emit OpenPsychosphere(msg.sender, _id);
    }

    function getPsychospheresOwner(uint256 _id) public view returns (address) {
        return psychosphereToOwner[_id];
    }

    function getPsychospheresCount(address user) public view returns (uint32) {
        return ownerPsychospheresCount[user];
    }

    function getOnePsychosphere(uint256 _id) public view returns (Psychosphere memory){
        require(psychosphereToOwner[_id] == msg.sender, "You not owner");
        return psychospheres[_id];
    }

    //get asset from psychospheres
    function getPsychospheresAsset(uint256 _id) public view returns(uint32){
        require(psychosphereToOwner[_id] == msg.sender, "Only owner of psycho");
        require(psychospheres[_id].opened == true, "Only open psycho");
        return psychosphereToAsset[_id];
    }

    //get all
    function getUserPsychospheres(address _owner) public view returns(uint256[] memory) {
        uint256[] memory result = new uint256[](ownerPsychospheresCount[_owner]);
        uint256 counter = 0;
        for (uint256 i = 0; i < psychospheres.length; i++) {
            if (psychosphereToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function transferPsychosphere(address recipient, uint256 ID) public {
        require(recipient != address(0), "to 0");
        require(psychosphereToOwner[ID] == msg.sender, "Your not owner");
        _transferPsychosphere(msg.sender, recipient, ID);
    }

    function transferPsychosphereFrom(address from, address to, uint256 ID) public {
        require(to != address(0), "to 0");
        bool currentAllowance = _allowances[from][msg.sender][ID];
        require(currentAllowance == true, "You dont have allowance");
        _transferPsychosphere(from, to, ID);
    }

    function approvePsychosphere(address to, uint256 ID) public returns(bool) {
        require(psychosphereToOwner[ID] == msg.sender, "Your not owner");
        _approvePsychosphere(msg.sender, to, ID);
        return true;
    }

    function _transferPsychosphere(address _from, address _to, uint256 _ID) private {
        psychosphereToOwner[_ID] = _to;
        ownerPsychospheresCount[_from] = ownerPsychospheresCount[_from].sub(1);
        ownerPsychospheresCount[_to] = ownerPsychospheresCount[_to].add(1);
        _deleteApprove(_from, _to, _ID);
        emit TransferPsychosphere(_from, _to, _ID);
    }

    function _approvePsychosphere(
        address owner,
        address spender,
        uint256 ID
    ) private {
        require(owner != address(0), "Psycho: from zero");
        require(spender != address(0), "Psycho: to zero");

        _allowances[owner][spender][ID] = true;
        emit ApprovalPsychosphere(owner, spender, ID);
    }

    function _deleteApprove(
        address owner,
        address spender,
        uint256 ID
    ) private {
        require(owner != address(0), "Psycho: delete approve from zero");
        require(spender != address(0), "Psycho: delete approve to zero");

        _allowances[owner][spender][ID] = false;
        emit DeleteApprove(owner, spender, ID);
    }

    modifier assetsContractIsSet() {
        require(address(assetsContract) != address(0), "Assets not set");
        _;
    }

    modifier onlyGame() {
        require(game == msg.sender, "Only game");
        _;
    }

    modifier onlyLab() {
        require(lab == msg.sender, "Only Lab");
        _;
    }

}
