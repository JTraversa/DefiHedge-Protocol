pragma solidity ^0.4.24;

import "./safeMath.sol";

contract Erc20 {
  function approve(address, uint) external returns (bool);
  function transfer(address, uint) external returns (bool);
  function balanceOf(address _owner) external returns (uint256 balance);
  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
}

contract CErc20 is Erc20 {
  function mint(uint) external returns (uint);
  function redeem(uint redeemTokens) external returns (uint);
}

contract CEth {
  function mint() external payable;
  function redeem(uint redeemTokens) external returns (uint);
  function balanceOf(address _owner) external returns (uint256 balance);
  function approve(address spender, uint tokens) public returns (bool success);
}
contract offerContract {
	address[] public contracts;
	
    event newFixedSideEthContract(
       address contractAddress,
       uint rate,
       uint duration,
       uint value
    );
    
    event newFloatingSideEthContract(
       address contractAddress,
       uint rate,
       uint duration,
       uint value
    );
    
    event newFixedSideErcContract(
       address contractAddress,
       uint rate,
       uint duration,
       address token,
       uint tokenNumber
    );
    
    event newFloatingSideErcContract(
       address contractAddress,
       uint rate,
       uint duration,
       address token,
       uint tokenNumber
    );

	constructor()
		public
	{
	}

	// deploy a new Eth fixed side lending contract
	function offerEthFixedSide( uint rate, uint duration)
		public
		payable
		returns(address newEthContract)
	{

		FixedSideEthContract EthContract = (new FixedSideEthContract).value(msg.value)(address(msg.sender), rate, duration);
		contracts.push(EthContract);
		emit newFixedSideEthContract(address(EthContract), rate, duration, msg.value);
		return EthContract;
	}
	
	// deploy a new Eth floating side lending contract
	function offerEthFloatingSide( uint rate, uint duration)
		public
		payable
		returns(address newEthContract)
	{

		FloatingSideEthContract EthContract = (new FloatingSideEthContract).value(msg.value)(address(msg.sender), rate, duration);
		contracts.push(EthContract);
		emit newFloatingSideEthContract(address(EthContract), rate, duration, msg.value);
		return EthContract;
	}	
	
	// deploy a new ERC20 fixed side lending contract
    function offerErcFixedSide( uint rate, uint duration, address erc20Contract, address cEr20Contract, uint tokenNumber)
		public
		payable
		returns(address newErcContract)
	{
        Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), tokenNumber);
		FixedSideErcContract ErcContract = (new FixedSideErcContract).value(0)(address(msg.sender), rate, duration, erc20Contract, cEr20Contract, tokenNumber);
		contracts.push(ErcContract);
		underlying.transfer(address(ErcContract), tokenNumber);
		emit newFixedSideErcContract(address(ErcContract), rate, duration, erc20Contract, tokenNumber);
		return ErcContract;
	}
	
		// deploy a new ERC20 fixed side lending contract
    function offerErcFloatingSide( uint rate, uint duration, address erc20Contract, address cEr20Contract, uint tokenNumber)
		public
		payable
		returns(address newErcContract)
	{
        Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), tokenNumber);
		FloatingSideErcContract ErcContract = (new FloatingSideErcContract).value(0)(address(msg.sender), rate, duration, erc20Contract, cEr20Contract, tokenNumber);
		contracts.push(ErcContract);
		underlying.transfer(address(ErcContract), tokenNumber);
		emit newFloatingSideErcContract(address(ErcContract), rate, duration, erc20Contract, tokenNumber);
		return ErcContract;
	}
	

}

contract FixedSideEthContract {
    uint public value;
	address public offerer;
	address public taker;
	uint public rate;
	uint public interest;
	uint public duration;
	uint public lockTime;
	enum State { Created, Locked, Inactive }
	State public state;

    using SafeMath for uint;
    
	constructor(address contractOfferer,  uint fixRate, uint termDuration) public payable {
		offerer = contractOfferer;
		value = msg.value;
		rate = fixRate;
		duration = termDuration;
		uint trueInterest = ((((rate.mul(value)).div(31622400)).div(100)).mul(duration));
		uint added = trueInterest.add(500000000000);
	    uint divided = added.div(1000000000000);
	    interest = divided.mul(1000000000000);
	}
	
	modifier onlyTaker() {
		require(msg.sender == taker);
		_;
	}

	modifier onlyOfferer() {
		require(msg.sender == offerer);
		_;
	}

	modifier inState(State _state) {
		require(state == _state);
		_;
	}

	event Aborted(address contractAddress);
	event OfferConfirmed(address contractAddress, uint rate, uint lockTime, uint value);
	event termEnded(address contractAddress);
	
	    
	/// Abort the offer and reclaim the ether.
	/// Can only be called by the offerer before
	/// the contract is locked.
	function abort()
		public
		onlyOfferer
		inState(State.Created)
	{
		emit Aborted(address(this));
		state = State.Inactive;
		offerer.transfer(address(this).balance);
	}

	/// Confirm the offer as taker.
	/// The ether will be locked until bondRelease
	function takeOffer()
		public
		inState(State.Created)
		payable
	{
	    require(msg.value >= interest);
		taker = msg.sender;
		state = State.Locked;
		lockTime = now + duration;
		mintCEther();
		emit OfferConfirmed(address(this), rate, lockTime, value);
	}
	/// Make contract payable
    function () public payable { }
    
	/// This will release the locked ether.
	function bondRelease()
		public
		inState(State.Locked)
	{
	    require(now > lockTime);
		emit termEnded(address(this));

		state = State.Inactive;
    
    /// Redeem CEther & return funds to respective parties
		redeemCEther();
		uint total = value.add(interest);
		offerer.transfer(total);
		taker.transfer(address(this).balance);
	}
	/// Mint Cether
	function mintCEther() internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth(CEthAdress).mint.value((value+interest))();
	    
	}
	/// Redeem Cether
	function redeemCEther() internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    uint balance = CEth(CEthAdress).balanceOf(address(this));
	    CEth(CEthAdress).redeem(balance);
	}
}

contract FixedSideErcContract {
    uint public tokenNumber;
    address public erc20Contract;
    address public cErc20Contract;
	address public offerer;
	address public taker;
	uint public rate;
	uint public interest;
	uint public duration;
	uint public lockTime;
	enum State { Created, Locked, Inactive }
	State public state;

    using SafeMath for uint;
    
	constructor(address contractOfferer,  uint fixRate, uint termDuration, address ercContract, address cErcContract, uint tokenNum) public payable {
		offerer = contractOfferer;
		rate = fixRate;
		duration = termDuration;
		tokenNumber = tokenNum;
        erc20Contract = ercContract;
        cErc20Contract = cErcContract;
		uint trueInterest = ((((rate.mul(tokenNumber)).div(31622400)).div(100)).mul(duration));
		uint added = trueInterest.add(500000000000);
	    uint divided = added.div(1000000000000);
	    interest = divided.mul(1000000000000);
	}
	
	modifier onlyTaker() {
		require(msg.sender == taker);
		_;
	}

	modifier onlyOfferer() {
		require(msg.sender == offerer);
		_;
	}

	modifier inState(State _state) {
		require(state == _state);
		_;
	}

	event Aborted(address contractAddress);
	event OfferConfirmed(address contractAddress, uint rate, address token, uint lockTime, uint tokenNumber);
	event termEnded(address contractAddress);
	    
	/// Abort the offer and reclaim the ether.
	/// Can only be called by the offerer before
	/// the contract is locked.
	function abort()
		public
		onlyOfferer
		inState(State.Created)
	{
		emit Aborted(address(this));
		state = State.Inactive;
		offerer.transfer(address(this).balance);
	}

	/// Confirm the offer as taker.
	/// The token will be locked until bondRelease
	function takeOffer()
		public
		inState(State.Created)
		payable
	{
	    Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), interest);
		taker = msg.sender;
		state = State.Locked;
		lockTime = now + duration;
		mintCToken(erc20Contract, cErc20Contract, (tokenNumber+interest));
		emit OfferConfirmed(address(this), rate, erc20Contract, lockTime, tokenNumber);
	}
	/// Make contract payable
    function () public payable { }
    
	/// This will release the locked ether.
	function bondRelease()
		public
		inState(State.Locked)
	{
	    require(now > lockTime);
		emit termEnded(address(this));

		state = State.Inactive;
		
    // Create a reference to the underlying asset contract
        Erc20 underlying = Erc20(erc20Contract);
        
    /// Redeem cToken & return funds to respective parties
		redeemCToken(cErc20Contract);
		
		uint total = tokenNumber.add(interest);
		
		underlying.transfer(offerer, total);
		underlying.transfer(taker, address(this).balance);
	}
	/// Mint cToken
	function mintCToken(
      address _erc20Contract,
      address _cErc20Contract,
      uint256 _numTokensToSupply
    ) internal returns (uint) {
        
      // Create a reference to the underlying asset contract, like DAI.
      Erc20 underlying = Erc20(_erc20Contract);
    
      // Create a reference to the corresponding cToken contract, like cDAI
      CErc20 cToken = CErc20(_cErc20Contract);
    
      // Approve transfer on the ERC20 contract
      underlying.approve(_cErc20Contract, _numTokensToSupply);
    
      // Mint cTokens and return the result
      uint mintResult = cToken.mint(_numTokensToSupply);
      return mintResult;
    }
    	    
	/// Redeem cToken
	function redeemCToken(
        address _cErc20Contract) internal {
	    uint balance = CErc20(_cErc20Contract).balanceOf(address(this));
	    CErc20(_cErc20Contract).redeem(balance);
	}
}

contract FloatingSideErcContract {
    uint public tokenNumber;
    address public erc20Contract;
    address public cErc20Contract;
	address public offerer;
	address public taker;
	uint public rate;
	uint public nominal;
	uint public duration;
	uint public lockTime;
	enum State { Created, Locked, Inactive }
	State public state;

    using SafeMath for uint;
    
	constructor(address contractOfferer,  uint fixRate, uint termDuration, address ercContract, address cErcContract, uint tokenNum) public payable {
		offerer = contractOfferer;
		rate = fixRate;
		duration = termDuration;
		tokenNumber = tokenNum;
        erc20Contract = ercContract;
        cErc20Contract = cErcContract;
		uint trueNominal = (((tokenNumber.mul(31622400)).div((rate.div(100)).mul(duration))));
		uint added = trueNominal.add(500000000000);
	    uint divided = added.div(1000000000000);
	    nominal = divided.mul(1000000000000);
	}
	
	modifier onlyTaker() {
		require(msg.sender == taker);
		_;
	}

	modifier onlyOfferer() {
		require(msg.sender == offerer);
		_;
	}

	modifier inState(State _state) {
		require(state == _state);
		_;
	}

	event Aborted(address contractAddress);
	event OfferConfirmed(address contractAddress, uint rate, address token, uint lockTime, uint tokenNumber);
	event termEnded(address contractAddress);
	    
	/// Abort the offer and reclaim the ether.
	/// Can only be called by the offerer before
	/// the contract is locked.
	function abort()
		public
		onlyOfferer
		inState(State.Created)
	{
		emit Aborted(address(this));
		state = State.Inactive;
		offerer.transfer(address(this).balance);
	}

	/// Confirm the offer as taker.
	/// The token will be locked until bondRelease
	function takeOffer()
		public
		inState(State.Created)
		payable
	{
	    Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), nominal);
		taker = msg.sender;
		state = State.Locked;
		lockTime = now + duration;
		mintCToken(erc20Contract, cErc20Contract, (tokenNumber+nominal));
		emit OfferConfirmed(address(this), rate, erc20Contract, lockTime, tokenNumber);
	}
	/// Make contract payable
    function () public payable { }
    
	/// This will release the locked ether.
	function bondRelease()
		public
		inState(State.Locked)
	{
	    require(now > lockTime);
		emit termEnded(address(this));

		state = State.Inactive;
		
    // Create a reference to the underlying asset contract
        Erc20 underlying = Erc20(erc20Contract);
        
    /// Redeem cToken & return funds to respective parties
		redeemCToken(cErc20Contract);
		
		uint total = tokenNumber.add(nominal);
		
		underlying.transfer(taker, total);
		underlying.transfer(offerer, address(this).balance);
	}
	/// Mint cToken
	function mintCToken(
      address _erc20Contract,
      address _cErc20Contract,
      uint256 _numTokensToSupply
    ) internal returns (uint) {
        
      // Create a reference to the underlying asset contract, like DAI.
      Erc20 underlying = Erc20(_erc20Contract);
    
      // Create a reference to the corresponding cToken contract, like cDAI
      CErc20 cToken = CErc20(_cErc20Contract);
    
      // Approve transfer on the ERC20 contract
      underlying.approve(_cErc20Contract, _numTokensToSupply);
    
      // Mint cTokens and return the result
      uint mintResult = cToken.mint(_numTokensToSupply);
      return mintResult;
    }
    	    
	/// Redeem cToken
	function redeemCToken(
        address _cErc20Contract) internal {
	    uint balance = CErc20(_cErc20Contract).balanceOf(address(this));
	    CErc20(_cErc20Contract).redeem(balance);
	}
}

contract FloatingSideEthContract {
    uint public value;
	address public offerer;
	address public taker;
	uint public rate;
	uint public nominal;
	uint public duration;
	uint public lockTime;
	enum State { Created, Locked, Inactive }
	State public state;

    using SafeMath for uint;
    
	constructor(address contractOfferer,  uint fixRate, uint termDuration) public payable {
		offerer = contractOfferer;
		value = msg.value;
		rate = fixRate;
		duration = termDuration;
		uint trueNominal = (((value.mul(31622400)).div((rate.div(100)).mul(duration))));
		uint added = trueNominal.add(500000000000);
	    uint divided = added.div(1000000000000);
	    nominal = divided.mul(1000000000000);
	}
	
	modifier onlyTaker() {
		require(msg.sender == taker);
		_;
	}

	modifier onlyOfferer() {
		require(msg.sender == offerer);
		_;
	}

	modifier inState(State _state) {
		require(state == _state);
		_;
	}

	event Aborted(address contractAddress);
	event OfferConfirmed(address contractAddress, uint rate, uint lockTime, uint value);
	event termEnded(address contractAddress);
	
	    
	/// Abort the offer and reclaim the ether.
	/// Can only be called by the offerer before
	/// the contract is locked.
	function abort()
		public
		onlyOfferer
		inState(State.Created)
	{
		emit Aborted(address(this));
		state = State.Inactive;
		offerer.transfer(address(this).balance);
	}

	/// Confirm the offer as taker.
	/// The ether will be locked until bondRelease
	function takeOffer()
		public
		inState(State.Created)
		payable
	{
	    require(msg.value >= nominal);
		taker = msg.sender;
		state = State.Locked;
		lockTime = now + duration;
		mintCEther();
		emit OfferConfirmed(address(this), rate, lockTime, value);
	}
	/// Make contract payable
    function () public payable { }
    
	/// This will release the locked ether.
	function bondRelease()
		public
		inState(State.Locked)
	{
	    require(now > lockTime);
		emit termEnded(address(this));

		state = State.Inactive;
    
    /// Redeem CEther & return funds to respective parties
		redeemCEther();
		uint total = value.add(nominal);
		taker.transfer(total);
		offerer.transfer(address(this).balance);
	}
	/// Mint Cether
	function mintCEther() internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth(CEthAdress).mint.value((value+nominal))();
	    
	}
	/// Redeem Cether
	function redeemCEther() internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    uint balance = CEth(CEthAdress).balanceOf(address(this));
	    CEth(CEthAdress).redeem(balance);
	}
}