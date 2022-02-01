const GameContract = artifacts.require("Game");
const DigitalGolems = artifacts.require("DigitalGolems")
const AssetsContract = artifacts.require("Assets");
const Inventory = artifacts.require("Inventory")
const Digibytes = artifacts.require("Digibytes")
const Psychospheres = artifacts.require("Psychospheres")
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


contract('Game Session', async (accounts)=>{
    let game;
    let inventory;
    let DIG;
    let psycho;
    let store;
    let assets;
    let user = accounts[9];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","0","8","0","6","9","1"]
    let abilities = [];
    const psychospheres = ["2", "3"]
    before(async () => {
        game = await GameContract.new()
        inventory = await Inventory.new()
        assets = await AssetsContract.new()
        DIG = await DigitalGolems.new()
        store = await Store.new()
        psycho = await Psychospheres.new()
        // await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await game.setPsycho(psycho.address, {from: owner})
        await psycho.setGameContract(game.address)
        await inventory.setGameContract(game.address, {from: owner})
        await inventory.setStoreContract(store.address, {from:owner})
        await assets.setGame(game.address)
        await DIG.setGameAddress(game.address, {from: owner})
        await DIG.ownerMint(
            user,
            "tokenURIs",
            "0",
            "0",
            {from:owner}
        )
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            abilities[i] = await DIG.getNumAbilityInt(1, i);
        }
        await game.sessionResult(
            things,
            resources,
            augment,
            psychospheres,
            "1",
            user,
            {from: user}
        )
    })

    it("Should check added inventory", async ()=>{
        //getting user inventory
        let getResources = await inventory.getResources(user, {from: user})
        let getThings = await inventory.getThings(user, {from: user})
        let getAugment = await inventory.getAugmentations(user, {from: user})
        //should be equal to what we added
        for (let i = 0; i < augment.length; i++) {
            assert.equal(getAugment[i].toString(), augment[i])
        }
        for (let i = 0; i < things.length; i++) {
            assert.equal(getThings[i].toString(), things[i])
        }
        for (let i = 0; i < resources.length; i++) {
            assert.equal(getResources[i].toString(), resources[i])
        }
    })

    it("Should check psycho", async ()=>{
        assert.equal(
            (await psycho.getPsychospheresCount(user)).toString(),
            "5"
        )
        //because we added 2 psycho of one type, 25 - 1/4
        assert.equal(
            (await psycho.getSubstrate(user, "0")).toString(),
            "50"
        )
        //because we added 3 psycho of one type
        assert.equal(
            (await psycho.getSubstrate(user, "1")).toString(),
            "75"
        )
    })
    
    it("Should be decreased abilities", async ()=>{
        //after session we decreased abilities on 1
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            if (abilities[i] != 0) {
                assert.equal(
                    //abilities before
                    parseInt(abilities[i].toString()),
                    //abilities after + 1, (+1) because we decreased on 1
                    parseInt((await DIG.getNumAbilityInt(1, i)).toString()) + 1,
                    "Decreased ability"
                    )
            } else {
                //abilities that equals 0 didnt change
                assert.equal(
                    parseInt(abilities[i].toString()),
                    parseInt((await DIG.getNumAbilityInt(1, i)).toString()),
                    "Zero ability"
                    )
            }
        }
    })

}
)