const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { cons } = require("fp-ts/lib/NonEmptyArray2v");

describe("NFT", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function NFT() {
    // Contracts are deployed using the first signer/account by default
    const [
      owner,
      otherAccount,
      otherAccount2,
      otherAccount3,
      otherAccount4,
      otherAccount5,
      otherAccount6,
      otherAccount7,
      otherAccount8,
    ] = await ethers.getSigners();

    const Herd = await ethers.getContractFactory("AlienTrunk");
    const Whitelist = await ethers.getContractFactory("Whitelist");
    const BUSD = await ethers.getContractFactory("BUSD");
    const Vault = await ethers.getContractFactory("Vault");
    const Market = await ethers.getContractFactory("MARKETPLACE");

    const whitelist = await Whitelist.deploy();
    const busd = await BUSD.deploy();
    const vault = await Vault.deploy(
      [
        owner.address,
        otherAccount5.address,
        otherAccount6.address,
        otherAccount7.address,
        otherAccount8.address,
      ],
      busd.address,
      3
    );
    const market = await Market.deploy(
      busd.address,
      vault.address,
      whitelist.address
    );

    const herd = await Herd.deploy(
      "https://ipfs.io/ipfs/QmQ1M2uECufPiMcnAVe5ZR5HJjYXMtGmSUmJuFG6ZhseBv/",
      market.address
    );

    return {
      herd,
      busd,
      market,
      whitelist,
      owner,
      vault,
      otherAccount,
      otherAccount2,
      otherAccount3,
      otherAccount4,
      otherAccount5,
      otherAccount6,
      otherAccount7,
      otherAccount8,
    };
  }

  describe("Deployment", function () {
    it("NFT", async function () {
      const {
        herd,
        market,
        vault,
        whitelist,
        owner,
        busd,
        otherAccount,
        otherAccount2,
      } = await loadFixture(NFT);

      busd.transfer(otherAccount.address, ethers.utils.parseEther("1000"));
      busd
        .connect(otherAccount)
        .approve(market.address, ethers.utils.parseEther("1000"));
      await whitelist.addAddressToWhitelist(otherAccount.address);
      await herd.mintMany(10);

      await market.setPaused(false);
      await market.connect(otherAccount).setReferral(otherAccount2.address);

      await market.listItem(herd.address, 0, ethers.utils.parseEther("100"));
      await market.listItem(herd.address, 1, ethers.utils.parseEther("100"));
      await market.listItem(herd.address, 2, ethers.utils.parseEther("100"));
      await market.listItem(herd.address, 3, ethers.utils.parseEther("100"));

      console.log(await market.presaleStarted());

      await market.connect(otherAccount).presaleBuy(herd.address, 0);

      await market.endPresale();

      await market.connect(otherAccount).buy(herd.address, 1);

      console.log(await market.fetchListItems());
      console.log(await market.connect(otherAccount).fetchMyListItems());

      console.log(await market.getReferral(owner.address));

      console.log(await busd.balanceOf(otherAccount.address));

      console.log(await busd.balanceOf(vault.address));

      console.log(await busd.balanceOf(otherAccount2.address));

      //await market.setBuyBack(true);

      //await market.connect(otherAccount).buyBack(herd.address, 0);

      //expect(await herd.whitelist()).to.equal(whitelist.address);
    });
  });
});
