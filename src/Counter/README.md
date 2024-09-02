# Upgradeable Contract

컨트랙트를 업그레이드 가능하도록 만들기 위해서는

1. Proxy Contract
2. Upgradeable Contract

가 필요하다. 

**Question 1. 각 Proxy Contract 와 Upgradeable Contract 가 하는 역할이 무엇인지 생각해보자.**

> 정답 : Upgradeable Contract 에는 실제 로직이 존재한다. Proxy Contract 에는 Upgradeable Contract 의
주소와 Upgradeable Contract 를 delegatecall 로 호출하는 함수가 존재한다.

**Question 2. 컨트랙트 내의 데이터는 실제로 어디에 저장되는가? (Proxy Contract or Upgradeable Contract)**

> 정답 : Proxy Contract 에 저장된다. Proxy Contract 에서 delegatecall 로 Upgradeable Contract 를
호출하기 때문에 Proxy Contract 의 Storage Layer 에서 Upgradeable Contract 로직을 실행하기 때문이다.

---

OpenZeppelin 에서는 업그레이드 가능한 컨트랙트를 개발하기 위한 컨트랙트를 제공한다.
대표적으로 ERC1967Proxy (Proxy Contract) 와 UUPSUpgradeable (Upgradeable Contract) 가 있다.

과제에서는 UUPSUpgradeable 을 사용할 것이다.

먼저 CounterV1 에서는 UUPSUpgradeable 을 상속되어있다.

```solidity
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ICounterV1} from "./ICounterV1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CounterV1 is UUPSUpgradeable, OwnableUpgradeable, ICounterV1 {
    uint256 public counter;

    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
    }

    function increment() external {
        unchecked {
            ++counter;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

UUPSUpgradeable 을 상속받으면 `upgradeToAndCall()` 함수가 존재하며, 이 함수를 호출하고, 파라미터로
업그레이드할 컨트랙트 주소 및 업그레이드 후 호출할 calldata 를 넣어서 업그레이드할 수 있다.

이 때, `_authorizeUpgrade` 함수를 통해 authorization 을 한다.

CounterV1 에서는 

`function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}` 으로
`onlyOnwer` modifier 가 있기 때문에 contract owner 가 아닌 주소가 `upgradeToAndCall` 함수를 호출하면
실패하여 업그레이드가 불가능하다.

이렇게 `_authorizeUpgrade` 함수를 상속해서 업그레이드에 대한 검증을 추가할 수 있다.


# Assignment

CounterV1 는 counter 변수가 있고, increment 함수를 호출하여 누구나 counter 를 1 증가시킬 수 있다.
CounterV1 에 다음과 같은 기능을 추가하여 CounterV2 로 업그레이드하고자 한다.

## Assignment #1


```
CounterV2 컨트랙트를 구현해보자.
```

- counter 외에 3번 요구사항을 위한 `registeredUpgradeContracts` 이 생겼다. 변수 순서 등 변수가 올바르게 선언되었는지 확인해보자.

## Assignment #2

```
`increment` 등 기존 CounterV1 에 존재하는 함수를 구현하고, `reset` 함수를 추가하여 counter 를 0 으로 초기화시킬 수 있는 함수를 추가한다.
```

```
function reset() external {
    counter = 0;
}
```

## Assignment #3

```
보안 사고 발생 등으로 인하여 owner 지갑 프라이빗 키 탈취하게 되면 해커가 악의적인
컨트랙트로 변경하여 문제가 발생할 수 있다. 이를 방지하기 위해서, CounterV2 부터는 컨트랙트를 변경하려면 
컨트랙트 주소를 등록하고, 일정 시간이 지난 후에 업그레이드할 수 있게끔 변경하고자 한다. 
따라서 컨트랙트 업그레이드 로직을 다음과 같이 변경해보자.
```

- 먼저 업그레이드를 할 컨트랙트 주소를 컨트랙트에 등록한다. (`registerUpgradeContract`)
- 컨트랙트 등록 후 2주가 지나야 업그레이드 가능하도록 한다. (`authorizeUpgrade` 알맞게 함수를 수정해보자.)
- 2주 안에 `revokeUpgradeContract` 를 통해 컨트랙트 업그레이드를 취소시킬 수 있다.
