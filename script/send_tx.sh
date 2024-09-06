# 배포
forge script script/DeployDAO.s.sol --rpc-url http://localhost:8545 --broadcast
export USER_ADDR=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# 세팅
    # 투표 시작 시간 바꾸기 1블록으로
cast send $GOVERNOR "setVotingDelay(uint48)" 1 --private-key $PRIVATE_KEY
    # 투표 진행기간 바꾸기 1블록으로
cast send $GOVERNOR "setVotingPeriod(uint32)" 1 --private-key $PRIVATE_KEY

# 제안
    # governor에 proxy 컨트랙트의 increment() 함수를 실행을 제안
CALLDATAS=$(cast calldata "propose(address[],uint256[],bytes[],string)" "[$PROXY]" "[0]" "[0xd09de08a]" "increment()")
cast send $GOVERNOR $CALLDATAS --private-key $PRIVATE_KEY
    # proposed List 확인
cast call $GOVERNOR "getproposedList()" 
    # proposal state 확인
cast call $GOVERNOR "state(uint256)" $PROPOSALID
    # 투표 언제 시작하지
cast call $GOVERNOR "proposalSnapshot(uint256)(uint256)" $PROPOSALID
    # 투표 끝내기 (state가 active이어야 함(state:1))
cast send $GOVERNOR "endVoteEarly(uint256)" $PROPOSALID --private-key $PRIVATE_KEY
    # 투표 결과
cast call $GOVERNOR "proposalVotes(uint256)(uint256,uint256,uint256)" $PROPOSALID
    # 투표 결과(state:4) 처리하기
cast send $GOVERNOR "Queue(uint256)" $PROPOSALID --private-key $PRIVATE_KEY

# 토큰 // 왜 거버너가 아닌 토큰에서 이짓을 하나요 ?
    # 토큰 관련
        # 토큰 민팅
cast send $TOKEN "mint(address,uint256)" $USER_ADDR 1ether --private-key $PRIVATE_KEY
cast send $TOKEN "exchangeToken()" --value 1ether --private-key $PRIVATE_KEY
cast send $TOKEN "exchangeEther(uint256)" 1ether --private-key $PRIVATE_KEY
        # 토큰 잔액
cast call $TOKEN "balanceOf(address)(uint256)" $USER_ADDR
        # 토큰 총 발행량
cast call $TOKEN "totalSupply()(uint256)"
    # 투표 관련
        # 투표권 수 보기
cast call $TOKEN "getVotes(address)(uint256)" $USER_ADDR
        # 투표권 받기
cast send $TOKEN "delegate(address)" $USER_ADDR --private-key $PRIVATE_KEY
        # 투표 하기 (0:반대, 1:찬성, 2:기권)
cast send $GOVERNOR "castVote(uint256,uint8)" $PROPOSALID 1 --private-key $PRIVATE_KEY

# 기타
    # 현재 블록 넘버 혹은 타임스탬프 확인
cast block # cast block-number
cast call $GOVERNOR "hasVoted(uint256,address)" $PROPOSALID $USER_ADDR