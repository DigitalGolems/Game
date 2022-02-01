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


contract('Game Duel Without Payoff', async (accounts)=>{
    let game;
    let assets;
    let inventory;
    let psycho;
    let userLoser = accounts[9];
    let userWinner = accounts[8];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","2","8","1","6","9","1"]
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
        await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await game.setPsycho(psycho.address, {from:owner})
        await psycho.setGameContract(game.address)
        await assets.setGame(game.address)
        await assets.setPsycho(psycho.address)
        await DIG.setGameAddress(game.address, {from: owner})
        await inventory.setGameContract(game.address)
        await inventory.setStoreContract(store.address)
        await assets.addAssetByOwner(
            "11",
            "1",
            "https://someURL/1",
            "0",
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
        //amount of loses and wins before
        let userLoserCardIDLoseBefore = await game.getCardIDToLose(1)
        let userWinnerCardIDWinBefore= await game.getCardIDToWin(2)
        let userLoserLoseBefore = await game.getUserToLose(userLoser)
        let userWinnerWinBefore = await game.getUserToWin(userWinner) 
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
        //amount of loses and wins after
        let userLoserCardIDLoseAfter = await game.getCardIDToLose(1)
        let userWinnerCardIDWinAfter= await game.getCardIDToWin(2)
        let userLoserLoseAfter = await game.getUserToLose(userLoser)
        let userWinnerWinAfter = await game.getUserToWin(userWinner) 
        //loser loses 1 asset
        assert.equal(assetsUserLoserBefore.length, assetsUserLoserAfter.length + 1, "Loser assets")
        //winner gets 1 asset
        assert.equal(0, assetsUserWinnerAfter.length - 1, "Winner assets")
        //we randomly got 1 loser's something from inventory
        //heres we are checking whats different between invetory before and after PVP
        //what changed compared with before state  
        console.log(thingsUserLoserBefore.toString(), thingsUserLoserAfter.toString(), "Lose things before/after")
        console.log(thingsUserWinnerBefore.toString(), thingsUserWinnerAfter.toString(), "Win things before/after")
        console.log(resourcesUserLoserBefore.toString(), resourcesUserLoserAfter.toString(), "Lose Resources before/after")
        console.log(resourcesUserWinnerBefore.toString(), resourcesUserWinnerAfter.toString(), "Win Resources before/after")
        console.log(augmentUserLoserBefore.toString(), augmentUserLoserAfter.toString(), "Lose Augmentations before/after")
        console.log(augmentUserWinnerBefore.toString(), augmentUserWinnerAfter.toString(), "Win Augmentations before/after")
        for (let i = 0; i < parseInt((await inventory.getThingsAmount()).toString()); i++) {
            if (thingsUserLoserBefore[i].toString() != thingsUserLoserAfter[i].toString()) {
                assert.equal(thingsUserLoserBefore[i].toString(), parseInt(thingsUserLoserAfter[i].toString()) + 1, "Lose things")
                assert.equal(thingsUserWinnerBefore[i].toString(), parseInt(thingsUserWinnerAfter[i].toString()) - 1, "Win things")
            }
        }
        for (let i = 0; i < parseInt((await inventory.getResourcesAmount()).toString()); i++) {
            if (resourcesUserLoserBefore[i].toString() != resourcesUserLoserAfter[i].toString()) {
                assert.equal(resourcesUserLoserBefore[i].toString(), parseInt(resourcesUserLoserAfter[i].toString()) + 1, "Lose Resources")
                assert.equal(resourcesUserWinnerBefore[i].toString(), parseInt(resourcesUserWinnerAfter[i].toString()) - 1, "Win Resources")
            }
        }
        for (let i = 0; i < parseInt((await inventory.getAugmentationsAmount()).toString()); i++) {
            if (augmentUserLoserBefore[i].toString() != augmentUserLoserAfter[i].toString()) {
                assert.equal(augmentUserLoserBefore[i].toString(), parseInt(augmentUserLoserAfter[i].toString()) + 1, "Lose Augmentations")
                assert.equal(augmentUserWinnerBefore[i].toString(), parseInt(augmentUserWinnerAfter[i].toString()) - 1, "Win Augmentations")
            }
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