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
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function exchangeRateCurrent() external returns (uint);
}

contract CEth {
  function mint() external payable;
  function redeem(uint redeemTokens) external returns (uint);
  function balanceOf(address _owner) external returns (uint256 balance);
  function approve(address spender, uint tokens) public returns (bool success);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function exchangeRateCurrent() external returns (uint);
}

contract DefiHedge {
	
	struct bondContract {
    	address maker;
        address taker;
        uint side;
        address tokenAddress;
        address cTokenAddress;
        uint duration;
        uint rate;
        uint interest;
        uint base;
        uint lockTime;
        uint state;
        uint initialRate;
    }

    mapping (bytes32 => bondContract) bondContracts;
    
	bytes32[] public bondContractList;
	
    event newFixedSideEthContract(
       bytes32 offerKey,
       uint rate,
       uint duration,
       uint value
    );
    
    event newFloatingSideEthContract(
       bytes32 offerKey,
       uint rate,
       uint duration,
       uint value
    );
    
    event newFixedSideErcContract(
       bytes32 offerKey,
       uint rate,
       uint duration,
       address token,
       uint tokenNumber
    );
    
    event newFloatingSideErcContract(
       bytes32 offerKey,
       uint rate,
       uint duration,
       address token,
       uint tokenNumber
    );
    
    event Aborted(
        bytes32 offerKey
        );
        
    event termEnded(
        bytes32 offerKey
        );
    
    event Activated(
        bytes32 offerKey
        );

	constructor()
		public
	{
	}
	
    using SafeMath for uint;

    function getOffer(bytes32 offerKey)
    public
    view
    returns (address maker, uint side, uint state, uint duration, uint rate, uint base, uint interest, address tokenAddress)
    {
        maker = bondContracts[offerKey].maker;
        side = bondContracts[offerKey].side;
        state = bondContracts[offerKey].state;
        duration = bondContracts[offerKey].duration;
        rate = bondContracts[offerKey].rate;
        base = bondContracts[offerKey].base;
        interest = bondContracts[offerKey].interest;
        tokenAddress = bondContracts[offerKey].tokenAddress;
        return (maker, side, state, duration, rate, base, interest, tokenAddress);
    }
    
	// deploy a new Eth fixed side lending contract
	function createEthFixedOffer(uint rate, uint duration)
	public
	payable
	returns (bytes32 _offerKey)
	{   
	    uint trueInterest = ((((rate.mul(msg.value)).div(365 days)).div(100)).mul(duration));

	    bytes32 offerKey = keccak256(abi.encodePacked((uint2str(now.mul(1000))),(address2str(msg.sender))));
	    bondContract storage ethContract = bondContracts[offerKey];
	    
	    ethContract.maker = address(msg.sender);
	    ethContract.side = 0;
	    ethContract.tokenAddress = 0x0000000000000000000000000000000000000000;
	    ethContract.cTokenAddress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    ethContract.duration = duration;
	    ethContract.rate = rate;
	    ethContract.state = 0;
	    ethContract.base = msg.value;
	    ethContract.interest = ((trueInterest.add(5e11)).div(1e12)).mul(1e12);
	    
	    bondContractList.push(offerKey) -1;
	    
	    emit newFixedSideEthContract(offerKey, rate, duration, msg.value);
	    
	    return offerKey;
	}
	
	// deploy a new Eth floating side lending contract
	function createEthFloatingOffer(uint rate, uint duration)
	public
	payable
	returns (bytes32 _offerKey)
	{   

	    uint trueBase = (((msg.value.mul(365 days)).div((rate.div(100)).mul(duration))));
	    
	    address _address = address(msg.sender);	
	    bytes32 offerKey = keccak256(abi.encodePacked((uint2str(now.mul(1000))),(address2str(_address))));
	    bondContract storage ethContract = bondContracts[offerKey];
	    
	    ethContract.maker = address(msg.sender);
	    ethContract.side = 1;
	    ethContract.tokenAddress = 0x0000000000000000000000000000000000000000;
	    ethContract.cTokenAddress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    ethContract.duration = duration;
	    ethContract.rate = rate;
	    ethContract.state = 0;
	    ethContract.interest = msg.value;
        ethContract.base = (((trueBase.add(5e11)).div(1e12)).mul(1e12));	    
	    
	    bondContractList.push(offerKey) -1;

	    emit newFloatingSideEthContract(offerKey, rate, duration, msg.value);
	    
	    return offerKey;
	}
	
	// deploy a new ERC20 fixed side lending contract
    function createErcFixedOffer( uint rate, uint duration, address erc20Contract, address cErc20Contract, uint tokenNumber)
	public
	returns (bytes32 _offerKey)
	{   
	    
	    Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), tokenNumber);
	    
	    /// Hash time + user address to create a unique key
	    address _address = address(msg.sender);	    
	    bytes32 offerKey = keccak256(abi.encodePacked((uint2str(now.mul(1000))),(address2str(_address))));
	    bondContract storage ercContract = bondContracts[offerKey];
	    
	    ercContract.maker = address(msg.sender);
	    ercContract.side = 0;
	    ercContract.tokenAddress = erc20Contract;
	    ercContract.cTokenAddress = cErc20Contract;
	    ercContract.duration = duration;
	    ercContract.rate = rate;
	    ercContract.state = 0;
	    ercContract.base = tokenNumber;
	    ercContract.interest = ((((((ercContract.rate.mul(ercContract.base)).div(365 days)).div(100)).mul(ercContract.duration)).add(5e11)).div(1e12)).mul(1e12);
	    
	    bondContractList.push(offerKey) -1;
	    
	    emit newFixedSideErcContract(offerKey, rate, duration, erc20Contract, tokenNumber);
	    
	    return offerKey;
	}

	
		/// deploy a new ERC20 floating side lending contract
    function createErcFloatingOffer(uint rate, uint duration, address erc20Contract, address cErc20Contract, uint tokenNumber)
	public
	returns (bytes32 _offerKey)
	{
        Erc20 underlying = Erc20(erc20Contract);
	    underlying.transferFrom(msg.sender, address(this), tokenNumber);
	    
	    
	    uint trueBase = (((tokenNumber.mul(365 days)).div((rate.div(100)).mul(duration))));
	    
	    /// Hash time + user address to create a unique key
	    address _address = address(msg.sender);
	    bytes32 offerKey = keccak256(abi.encodePacked((uint2str(now.mul(1000))),(address2str(_address))));
	    bondContract storage ercContract = bondContracts[offerKey];
	    
	    ercContract.maker = address(msg.sender);
	    ercContract.side = 1;
	    ercContract.tokenAddress = erc20Contract;
	    ercContract.cTokenAddress = cErc20Contract;
	    ercContract.duration = duration;
	    ercContract.rate = rate;
	    ercContract.state = 0;
	    ercContract.interest = tokenNumber;
        ercContract.base = (((trueBase.add(5e11)).div(1e12)).mul(1e12));	    
        
	    bondContractList.push(offerKey) -1;
	    
	    emit newFloatingSideErcContract(offerKey, rate, duration, erc20Contract, tokenNumber);
	    
	    return offerKey;
	}
	
	function takeErcOffer(bytes32 offerKey)
	public
	{
	    if (bondContracts[offerKey].side == 0) {
    	    Erc20 underlying = Erc20(bondContracts[offerKey].tokenAddress);
    	    underlying.transferFrom(msg.sender, address(this), bondContracts[offerKey].interest);
    	    
    	    bondContracts[offerKey].lockTime = now + bondContracts[offerKey].duration;

            uint value = bondContracts[offerKey].interest.add(bondContracts[offerKey].base);
            
            mintCToken(bondContracts[offerKey].tokenAddress, bondContracts[offerKey].cTokenAddress, value, offerKey);
            
            bondContracts[offerKey].taker = msg.sender;
    	    bondContracts[offerKey].state = 1;
    	    emit Activated(offerKey);
	    }
	    
        if (bondContracts[offerKey].side == 1) {
    	    underlying = Erc20(bondContracts[offerKey].tokenAddress);
    	    underlying.transferFrom(msg.sender, address(this), bondContracts[offerKey].base);
    	    
    	    bondContracts[offerKey].lockTime = now + bondContracts[offerKey].duration;
    	    
    	    value = bondContracts[offerKey].interest.add(bondContracts[offerKey].base);
            
            mintCToken(bondContracts[offerKey].tokenAddress, bondContracts[offerKey].cTokenAddress, value, offerKey);
            
            bondContracts[offerKey].taker = msg.sender;
    	    bondContracts[offerKey].state = 1;
    	    emit Activated(offerKey);
        }
	}
	
	function takeEthOffer(bytes32 offerKey)
	public
	payable
	{
	    if (bondContracts[offerKey].side == 0) {
    	    require(msg.value >= bondContracts[offerKey].interest);
    	    
    	    uint value = bondContracts[offerKey].interest.add(bondContracts[offerKey].base);
            
            mintCEther(value, offerKey);
            
            bondContracts[offerKey].lockTime = now + bondContracts[offerKey].duration;
    	    
    	    bondContracts[offerKey].taker = msg.sender;
    	    bondContracts[offerKey].state = 1;
    	    
            emit Activated(offerKey);
	    }
	    
	    if (bondContracts[offerKey].side == 1) {
    	    require(msg.value >= bondContracts[offerKey].base);
    	    
    	    value = bondContracts[offerKey].interest.add(bondContracts[offerKey].base);
            
            mintCEther(value, offerKey);
            
            bondContracts[offerKey].lockTime = now + bondContracts[offerKey].duration;
    	    
    	    bondContracts[offerKey].taker = msg.sender;
    	    bondContracts[offerKey].state = 1;
            
            emit Activated(offerKey);
	    }
	}
	
	 /// Abort an offer
	function abort(bytes32 offerKey)
	public
	{
	    require(msg.sender == bondContracts[offerKey].maker);
	    require(bondContracts[offerKey].state == 0)
		emit Aborted(offerKey);
		
		/// Return funds to maker
		if (bondContracts[offerKey].side == 1) {
		bondContracts[offerKey].maker.transfer(bondContracts[offerKey].interest);    
		bondContracts[offerKey].state = 2;
		}
		if (bondContracts[offerKey].side == 0) {
		bondContracts[offerKey].maker.transfer(bondContracts[offerKey].base);    
		bondContracts[offerKey].state = 2;
		}
	}
	
	 /// Release an Eth bond once if term completed
	function releaseEthBond(bytes32 offerKey)
	public
	{
	    require(now > bondContracts[offerKey].lockTime);
        
    /// Redeem CEther & return funds to respective parties
		
		address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth cEth = CEth(CEthAdress);
	    
		uint total = bondContracts[offerKey].base.add(bondContracts[offerKey].interest);
		uint avgRate = (cEth.exchangeRateCurrent().sub(bondContracts[offerKey].initialRate)).div(bondContracts[offerKey].initialRate);
		
		if (bondContracts[offerKey].side == 0) {
		
    		if (avgRate > bondContracts[offerKey].rate) {
    		    uint floatingProfit = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
    		    uint floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
    		    redeemCEther((total.add(floatingReturned)));
    	        bondContracts[offerKey].maker.transfer(total);
    	        bondContracts[offerKey].taker.transfer(floatingReturned);
    	        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
    		    }
    		    
    		if (avgRate < bondContracts[offerKey].rate){
    		    uint floatingOwed = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
    		    floatingReturned = floatingOwed.add(bondContracts[offerKey].interest);
    		    redeemCEther((total.add(floatingReturned)));
    		    bondContracts[offerKey].maker.transfer(total);
    		    bondContracts[offerKey].taker.transfer(floatingReturned);
    		    emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
    		    }
		
		}
		
		if (bondContracts[offerKey].side == 1) {
        
    		if (avgRate > bondContracts[offerKey].rate) {
    		    floatingProfit = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
    		    floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
    		    redeemCEther((total.add(floatingReturned)));
    	        bondContracts[offerKey].maker.transfer(floatingReturned);
    	        bondContracts[offerKey].taker.transfer(total);
    	        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
    		    }
    		    
    		if (avgRate < bondContracts[offerKey].rate){
    		    floatingOwed = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
    		    floatingReturned = floatingOwed.add(bondContracts[offerKey].interest);
    		    redeemCEther((total.add(floatingReturned)));
    		    bondContracts[offerKey].maker.transfer(floatingReturned);
    		    bondContracts[offerKey].taker.transfer(total);
    		    emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
    		    }
		
		}
		
		
	}
	
	 /// Release an ERC bond once if term completed
	function releaseErcBond(bytes32 offerKey)
	public
	{
	    address cTokenAddress = bondContracts[offerKey].cTokenAddress;
	    address tokenAddress = bondContracts[offerKey].tokenAddress;
	    
	    Erc20 underlying = Erc20(tokenAddress);
	    CErc20 cToken = CErc20(cTokenAddress);

    /// Calculate interests, Redeem cTokens & return funds to respective parties	    
	    uint total = bondContracts[offerKey].base.add(bondContracts[offerKey].interest);
		uint avgRate = (cToken.exchangeRateCurrent().sub(bondContracts[offerKey].initialRate)).div(bondContracts[offerKey].initialRate);
		
        if (bondContracts[offerKey].side == 0) {
		    
		    if (avgRate > bondContracts[offerKey].rate) {
		        uint floatingProfit = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
		        uint floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
		        redeemCToken(cTokenAddress,(total.add(floatingReturned)));
		        underlying.transfer(bondContracts[offerKey].maker, total);
		        underlying.transfer(bondContracts[offerKey].taker, floatingReturned);
		        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
		    }
		    
		    if (avgRate < bondContracts[offerKey].rate){
		        uint floatingOwed = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
		        floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
		        redeemCToken(cTokenAddress,(total.add(floatingReturned)));
		        underlying.transfer(bondContracts[offerKey].maker, total);
		        underlying.transfer(bondContracts[offerKey].taker, floatingReturned);
		        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
		    }      
		    
        }
        
        if (bondContracts[offerKey].side == 1) {
		    
		    if (avgRate > bondContracts[offerKey].rate) {
		        floatingProfit = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
		        floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
		        redeemCToken(cTokenAddress,(total.add(floatingReturned)));
		        underlying.transfer(bondContracts[offerKey].maker, floatingReturned);
		        underlying.transfer(bondContracts[offerKey].taker, total);
		        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
		    }
		    
		    if (avgRate < bondContracts[offerKey].rate){
		        floatingOwed = (avgRate.sub(bondContracts[offerKey].rate)).mul(total);
		        floatingReturned = floatingProfit.add(bondContracts[offerKey].interest);
		        redeemCToken(cTokenAddress,(total.add(floatingReturned)));
		        underlying.transfer(bondContracts[offerKey].maker, floatingReturned);
		        underlying.transfer(bondContracts[offerKey].taker, total);
		        emit termEnded(offerKey);
		        bondContracts[offerKey].state = 2;
		    }      
        }
	}
	
		/// Mint Cether
	function mintCEther(uint value, bytes32 offerKey) internal {
	    
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth cEth = CEth(CEthAdress);

	    bondContracts[offerKey].initialRate = cEth.exchangeRateCurrent();
	    
	    cEth.mint.value((value))();
	    
	}
	    /// Redeem Cether
	function redeemCEther(uint value) internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth cEth = CEth(CEthAdress);
	    cEth.redeemUnderlying(value);
	}
	
		/// Mint cToken
	function mintCToken(
      address _erc20Contract,
      address _cErc20Contract,
      uint _numTokensToSupply,
      bytes32 offerKey
    ) internal returns (uint) {
        
      Erc20 underlying = Erc20(_erc20Contract);

      CErc20 cToken = CErc20(_cErc20Contract);
      
      // Approve transfer on the ERC20 contract
      underlying.approve(_cErc20Contract, _numTokensToSupply);
      
      bondContracts[offerKey].initialRate = cToken.exchangeRateCurrent();
      
      uint mintResult = cToken.mint(_numTokensToSupply);
      return mintResult;
    }
    	    
	    /// Redeem cToken
	function redeemCToken(
        address _cErc20Contract, uint _numTokensToRedeem) internal {
	    CErc20(_cErc20Contract).redeemUnderlying(_numTokensToRedeem);
	}

    function uint2str(uint i) internal pure returns (string){
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        while (i != 0){
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }
    function address2str(address x) internal pure returns (string) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
}
}

