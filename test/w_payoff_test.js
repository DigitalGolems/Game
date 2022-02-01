const GameContract = artifacts.require("Game");
const DigitalGolems = artifacts.require("DigitalGolems")
const AssetsContract = artifacts.require("Assets");
const Psychospheres = artifacts.require("Psychospheres")
const Inventory = artifacts.require("Inventory")
const Digibytes = artifacts.require("Digibytes")
const Store = artifacts.require("Store")

const { assert } = require("chai");
const {
    catchRevert,            
    catchOutOfGas,          
    catchInvalidJump,       
    catchInvalidOpcode,     
    catchStackOverflow,     
    catchStackUnderflow,   
    catchStaticStateChange
} = require("../../utils/catch_error.js")


contract('Game Duel With Payoff', async (accounts)=>{
    let game;
    let assets;
    let inventory;
    let store;
    let psycho;
    let userLoser = accounts[9];
    let userWinner = accounts[8];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","0","8","0","6","9","1"]
    let abilities = [];
    const tokenURIs = [
        "https://ipfs.io/ipfs/QmUdTP3VBY5b9u1Bdc3AwKggQMg5TQyNXVfzgcUQKjdmRH"
    ]
    const kinds = [1]
    const series = [1]
    const psychospheres = ["2", "3"]
    before(async () => {
        assets = await AssetsContract.new()
        game = await GameContract.new()
        inventory = await Inventory.new()
        DIG = await DigitalGolems.new()
        DBT = await Digibytes.new()
        store = await Store.new()
        psycho = await Psychospheres.new()
        await DBT.transfer(userLoser, web3.utils.toWei("10"))
        await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await game.setPsycho(psycho.address, {from:owner})
        await psycho.setGameContract(game.address)
        await inventory.setGameContract(game.address)
        await inventory.setStoreContract(store.address)
        await assets.setGame(game.address)
        await DIG.setGameAddress(game.address, {from: owner})
        await assets.addAssetByOwner(
            "11",//layer
            "1",//part
            "https://someURL/1", //uri
            "0", //rarity
            {from: owner}
        )
        await assets.addAssetByOwner(
            "12",
            "2",
            "https://someURL/2",
            "0",
            {from: owner}
        )
        await assets.addUserToAssetOwner(0, userLoser, {from:owner})
        await assets.addUserToAssetOwner(1, userLoser, {from:owner})
        await DIG.ownerMint(
            userLoser,
            tokenURIs[0],
            kinds[0],
            series[0]
        )
        await DIG.ownerMint(
            userWinner,
            tokenURIs[0],
            kinds[0],
            series[0]
        )
        await game.sessionResult(
            things,
            resources,
            augment,
            psychospheres,
            "1",
            userLoser,
            {from: userLoser}
        )
    })

    it("Should duel", async ()=>{
        //all users assets and inventory before PVP
        let assetsUserLoserBefore = await assets.getAllUserAssets(userLoser)
        let thingsUserLoserBefore = await inventory.getThings(userLoser)
        let resourcesUserLoserBefore = await inventory.getResources(userLoser)
        let augmentUserLoserBefore = await inventory.getAugmentations(userLoser)
        let thingsUserWinnerBefore = await inventory.getThings(userWinner)
        let resourcesUserWinnerBefore = await inventory.getResources(userWinner)
        let augmentUserWinnerBefore = await inventory.getAugmentations(userWinner)
        //amount of loses and wins statistics before
        let userLoserCardIDLoseBefore = await game.getCardIDToLose(1)
        let userWinnerCardIDWinBefore= await game.getCardIDToWin(2)
        let userLoserLoseBefore = await game.getUserToLose(userLoser)
        let userWinnerWinBefore = await game.getUserToWin(userWinner) 
        //payoff
        await DBT.approve(game.address, web3.utils.toWei("10"), {from: userLoser})
        await game.payoff(userLoser)
        //write PVP result
        const message = web3.utils.soliditySha3(
            game.address,
            userWinner,
            userWinnerWinBefore
            );
        const signWinner = await web3.eth.sign(message, owner)
        const r = signWinner.substr(0, 66)
        const s = '0x' + signWinner.substr(66, 64);
        const v = web3.utils.toDecimal("0x" + (signWinner.substr(130,2) == 0 ? "1b" : "1c"));//до сюда, делается серваком
        await game.PVPResultWinner(userWinner, 2, userLoser, 1, v, r, s, {from: userWinner})
        //all users assets and inventory after PVP
        let assetsUserLoserAfter = await assets.getAllUserAssets(userLoser)
        let thingsUserLoserAfter = await inventory.getThings(userLoser)
        let resourcesUserLoserAfter = await inventory.getResources(userLoser)
        let augmentUserLoserAfter = await inventory.getAugmentations(userLoser)
        let assetsUserWinnerAfter = await assets.getAllUserAssets(userWinner)
        let thingsUserWinnerAfter = await inventory.getThings(userWinner)
        let resourcesUserWinnerAfter = await inventory.getResources(userWinner)
        let augmentUserWinnerAfter = await inventory.getAugmentations(userWinner)
        //amount of loses and wins statistics after
        let userLoserCardIDLoseAfter = await game.getCardIDToLose(1)
        let userWinnerCardIDWinAfter= await game.getCardIDToWin(2)
        let userLoserLoseAfter = await game.getUserToLose(userLoser)
        let userWinnerWinAfter = await game.getUserToWin(userWinner) 
        //loser loses 0 asset because was payoff
        assert.equal(assetsUserLoserBefore.length, assetsUserLoserAfter.length, "Loser assets")
        //winner gets 0 asset because was payoff
        assert.equal(0, assetsUserWinnerAfter.length, "Winner assets")
        //winventory w/o changing because was payoff
        for (let i = 0; i < parseInt((await inventory.getThingsAmount()).toString()); i++) {
            assert.equal(thingsUserLoserBefore[i].toString(), parseInt(thingsUserLoserAfter[i].toString()), "Didnt Lose things")
            assert.equal(thingsUserWinnerBefore[i].toString(), parseInt(thingsUserWinnerAfter[i].toString()), "Didnt Win things")
        }
        for (let i = 0; i < parseInt((await inventory.getResourcesAmount()).toString()); i++) {
            assert.equal(resourcesUserLoserBefore[i].toString(), parseInt(resourcesUserLoserAfter[i].toString()), "Didnt Lose Resources")
            assert.equal(resourcesUserWinnerBefore[i].toString(), parseInt(resourcesUserWinnerAfter[i].toString()), "Didnt Win Resources")
        }
        for (let i = 0; i < parseInt((await inventory.getAugmentationsAmount()).toString()); i++) {
            assert.equal(augmentUserLoserBefore[i].toString(), parseInt(augmentUserLoserAfter[i].toString()), "Didnt Lose Augmentations")
            assert.equal(augmentUserWinnerBefore[i].toString(), parseInt(augmentUserWinnerAfter[i].toString()), "Didnt Win Augmentations")
        }
        //check if statistics of losing and winning added
        assert.equal(
            parseInt(userLoserCardIDLoseBefore.toString()),
            parseInt(userLoserCardIDLoseAfter.toString()) - 1,
            "Loses card added"
        )
        assert.equal(
            parseInt(userWinnerCardIDWinBefore.toString()),
            parseInt(userWinnerCardIDWinAfter.toString()) - 1,
            "Winner card added"
        )
        assert.equal(
            parseInt(userLoserLoseBefore.toString()),
            parseInt(userLoserLoseAfter.toString()) - 1,
            "Loser added"
        )
        assert.equal(
            parseInt(userWinnerWinBefore.toString()),
            parseInt(userWinnerWinAfter.toString()) - 1,
            "Winner added"
        )
    })

}
)