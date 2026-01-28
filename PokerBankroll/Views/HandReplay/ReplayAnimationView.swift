import SwiftUI
import UIKit

struct ReplayAnimationView: View {
    let hand: PokerHand
    @Environment(\.dismiss) var dismiss

    @State private var currentActionIndex = -1
    @State private var isPlaying = false
    @State private var players: [PlayerState] = []
    @State private var visibleBoardCards = 0
    @State private var pot: Double = 0
    @State private var currentStreet: Street = .preflop
    @State private var showHoleCards = false
    @State private var completedSteps = 0
    @State private var showShareAlert = false

    private var totalSteps: Int {
        // Steps: Show hole cards (1) + each action + board reveals
        return 1 + hand.actions.count + boardRevealSteps
    }

    private var boardRevealSteps: Int {
        var steps = 0
        if hand.flop.count == 3 { steps += 1 }
        if hand.turn != nil { steps += 1 }
        if hand.river != nil { steps += 1 }
        return steps
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Poker Table
                tableArea
                    .frame(maxHeight: .infinity)

                // Current Action Display
                actionDisplay

                // Controls
                controls
            }
        }
        .onAppear {
            setupPlayers()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.black)
                    .padding(8)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(hand.stakes)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Hero: \(hand.heroPosition)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    shareHand()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("POT")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("$\(Int(pot))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .alert("Replayer Copied!", isPresented: $showShareAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Interactive hand replayer copied! Paste into a .html file and open in any browser to play.")
        }
    }

    // MARK: - Table Area

    private var tableArea: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let centerY = height / 2
            // Make table smaller to leave room for player labels
            let tableWidth = width * 0.65
            let tableHeight = height * 0.45

            ZStack {
                // Table
                tableShape(width: tableWidth, height: tableHeight)
                    .position(x: centerX, y: centerY)

                // Community Cards
                communityCardsView
                    .position(x: centerX, y: centerY - 15)

                // Pot Display
                if pot > 0 {
                    Text("$\(Int(pot))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 3)
                        )
                        .position(x: centerX, y: centerY + 35)
                }

                // Players around the table
                ForEach(players) { player in
                    let pos = playerPosition(
                        for: player.position,
                        centerX: centerX,
                        centerY: centerY,
                        radiusX: tableWidth / 2 + 50,
                        radiusY: tableHeight / 2 + 55
                    )

                    // Clamp positions to stay within bounds
                    let clampedX = max(45, min(width - 45, pos.x))
                    let clampedY = max(40, min(height - 40, pos.y))

                    ReplayPlayerView(player: player, showCards: shouldShowCards(for: player))
                        .position(x: clampedX, y: clampedY)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Table Shape

    private func tableShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Outer border
            Ellipse()
                .stroke(Color.black, lineWidth: 3)
                .frame(width: width, height: height)

            // Inner felt
            Ellipse()
                .fill(Color.black.opacity(0.03))
                .frame(width: width - 10, height: height - 10)

            // Inner border
            Ellipse()
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                .frame(width: width - 20, height: height - 20)
        }
    }

    // MARK: - Community Cards

    private var communityCardsView: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                if index < visibleBoardCards && index < hand.board.count {
                    CardView(card: hand.board[index], size: .small)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: 32, height: 44)
                }
            }
        }
        .animation(.spring(response: 0.4), value: visibleBoardCards)
    }

    // MARK: - Action Display

    private var actionDisplay: some View {
        VStack(spacing: 8) {
            // Street indicator
            HStack(spacing: 12) {
                ForEach(Street.allCases, id: \.self) { street in
                    Text(street.rawValue)
                        .font(.caption)
                        .fontWeight(currentStreet == street ? .bold : .regular)
                        .foregroundColor(currentStreet == street ? .black : .gray)
                }
            }

            // Current action
            if currentActionIndex >= 0 && currentActionIndex < hand.actions.count {
                let action = hand.actions[currentActionIndex]
                HStack(spacing: 8) {
                    Text(action.position)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(action.isHero ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(action.isHero ? Color.black : Color.black.opacity(0.1))
                        )

                    Text(action.action.rawValue.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)

                    if let amount = action.amount, amount > 0 {
                        Text("$\(Int(amount))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if currentActionIndex == -1 {
                Text("Press play to start")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 80)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.25), value: currentActionIndex)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Control buttons
            HStack(spacing: 28) {
                Button { reset() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { previousStep() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black))
                }

                Button { nextStep() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { skipToEnd() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }
            }

            // Result display
            if currentActionIndex >= hand.actions.count - 1 || !isPlaying && currentActionIndex == hand.actions.count - 1 {
                HStack {
                    Text("Result:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(formatResult(hand.result))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(hand.result >= 0 ? .black : .gray)
                }
            }
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Helper Methods

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(completedSteps) / CGFloat(totalSteps)
    }

    private func setupPlayers() {
        players = PlayerPosition.allPositions.map { position in
            var state = PlayerState(
                position: position,
                isActive: true,
                isHero: position.shortName == hand.heroPosition
            )
            if position.shortName == hand.heroPosition {
                state.cards = hand.holeCards
            }
            return state
        }
    }

    private func shouldShowCards(for player: PlayerState) -> Bool {
        return showHoleCards && player.isHero
    }

    private func playerPosition(
        for position: PlayerPosition,
        centerX: CGFloat,
        centerY: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat
    ) -> CGPoint {
        let angle = position.angle * .pi / 180
        let x = centerX + radiusX * cos(angle)
        let y = centerY + radiusY * sin(angle)
        return CGPoint(x: x, y: y)
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            autoPlay()
        }
    }

    private func autoPlay() {
        guard isPlaying else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if isPlaying {
                if !nextStep() {
                    isPlaying = false
                } else {
                    autoPlay()
                }
            }
        }
    }

    @discardableResult
    private func nextStep() -> Bool {
        // First step: show hole cards
        if !showHoleCards {
            withAnimation {
                showHoleCards = true
                completedSteps = 1
            }
            return true
        }

        // Check for board reveals based on current action
        let nextActionIndex = currentActionIndex + 1
        if nextActionIndex < hand.actions.count {
            let nextAction = hand.actions[nextActionIndex]

            // Check if we need to reveal board cards before this action
            if nextAction.street == .flop && visibleBoardCards == 0 && hand.flop.count == 3 {
                withAnimation {
                    visibleBoardCards = 3
                    currentStreet = .flop
                    completedSteps += 1
                }
                return true
            } else if nextAction.street == .turn && visibleBoardCards == 3 && hand.turn != nil {
                withAnimation {
                    visibleBoardCards = 4
                    currentStreet = .turn
                    completedSteps += 1
                }
                return true
            } else if nextAction.street == .river && visibleBoardCards == 4 && hand.river != nil {
                withAnimation {
                    visibleBoardCards = 5
                    currentStreet = .river
                    completedSteps += 1
                }
                return true
            }

            // Process the action
            currentActionIndex = nextActionIndex
            let action = hand.actions[currentActionIndex]

            withAnimation {
                currentStreet = action.street
                completedSteps += 1

                // Update player state
                if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                    players[index].lastAction = action.action
                    if action.action == .fold {
                        players[index].isFolded = true
                    }
                    if let amount = action.amount {
                        players[index].currentBet = amount
                        pot += amount
                    }
                }
            }
            return true
        }

        // Reveal remaining board cards if any
        if visibleBoardCards < hand.board.count {
            withAnimation {
                if visibleBoardCards == 0 && hand.flop.count == 3 {
                    visibleBoardCards = 3
                    currentStreet = .flop
                    completedSteps += 1
                } else if visibleBoardCards == 3 && hand.turn != nil {
                    visibleBoardCards = 4
                    currentStreet = .turn
                    completedSteps += 1
                } else if visibleBoardCards == 4 && hand.river != nil {
                    visibleBoardCards = 5
                    currentStreet = .river
                    completedSteps += 1
                }
            }
            return true
        }

        return false
    }

    private func previousStep() {
        guard completedSteps > 0 else { return }

        if currentActionIndex >= 0 {
            // Undo the current action
            let action = hand.actions[currentActionIndex]
            if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                players[index].lastAction = nil
                players[index].isFolded = false
                if let amount = action.amount {
                    pot -= amount
                }
                players[index].currentBet = 0
            }
            currentActionIndex -= 1
            completedSteps -= 1

            // Update street
            if currentActionIndex >= 0 {
                currentStreet = hand.actions[currentActionIndex].street
            } else {
                currentStreet = .preflop
            }

            // Hide board if going back to preflop
            updateBoardVisibility()
        } else if showHoleCards {
            showHoleCards = false
            completedSteps = 0
        }
    }

    private func updateBoardVisibility() {
        if currentActionIndex < 0 {
            visibleBoardCards = 0
        } else {
            let street = hand.actions[currentActionIndex].street
            switch street {
            case .preflop:
                visibleBoardCards = 0
            case .flop:
                visibleBoardCards = 3
            case .turn:
                visibleBoardCards = 4
            case .river:
                visibleBoardCards = 5
            }
        }
    }

    private func reset() {
        isPlaying = false
        currentActionIndex = -1
        showHoleCards = false
        visibleBoardCards = 0
        pot = 0
        currentStreet = .preflop
        completedSteps = 0
        setupPlayers()
    }

    private func skipToEnd() {
        isPlaying = false
        showHoleCards = true
        visibleBoardCards = hand.board.count
        currentActionIndex = hand.actions.count - 1
        completedSteps = totalSteps

        if let lastAction = hand.actions.last {
            currentStreet = lastAction.street
        }

        // Calculate final pot and update all player states
        pot = 0
        setupPlayers()
        for action in hand.actions {
            if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                players[index].lastAction = action.action
                if action.action == .fold {
                    players[index].isFolded = true
                }
                if let amount = action.amount {
                    pot += amount
                }
            }
        }
    }

    private func formatResult(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    // MARK: - Share Hand

    private func shareHand() {
        let htmlReplayer = generateHTMLReplayer()
        UIPasteboard.general.string = htmlReplayer
        showShareAlert = true
    }

    private func generateHTMLReplayer() -> String {
        // Convert hand data to JSON-safe format
        let holeCardsJS = hand.holeCards.map { "'\($0.rank.display)\(getSuitSymbol($0.suit))'" }.joined(separator: ", ")
        let boardJS = hand.board.map { "'\($0.rank.display)\(getSuitSymbol($0.suit))'" }.joined(separator: ", ")

        var actionsJS = "["
        for (index, action) in hand.actions.enumerated() {
            let amountStr = action.amount != nil ? "\(Int(action.amount!))" : "null"
            actionsJS += "{street:'\(action.street.rawValue)',pos:'\(action.position)',action:'\(action.action.rawValue)',amount:\(amountStr),hero:\(action.isHero)}"
            if index < hand.actions.count - 1 { actionsJS += "," }
        }
        actionsJS += "]"

        return """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>Poker Hand - \(hand.stakes) - \(hand.heroPosition)</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000;min-height:100vh;display:flex;flex-direction:column}
.container{max-width:500px;margin:0 auto;padding:16px;width:100%}
.header{text-align:center;padding:12px;border-bottom:1px solid #eee}
.header h2{font-size:18px;margin-bottom:4px}
.header .sub{color:#666;font-size:13px}
.table-area{position:relative;width:100%;padding-top:70%;margin:16px 0}
.table{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:65%;height:60%;border:3px solid #000;border-radius:50%;background:#fafafa}
.pot{position:absolute;top:55%;left:50%;transform:translate(-50%,-50%);background:#fff;padding:4px 12px;border-radius:20px;font-weight:bold;font-size:14px;box-shadow:0 2px 4px rgba(0,0,0,.1)}
.board{position:absolute;top:42%;left:50%;transform:translate(-50%,-50%);display:flex;gap:4px}
.card{width:32px;height:44px;background:#fff;border:1px solid #ddd;border-radius:4px;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:11px;font-weight:bold;box-shadow:0 1px 2px rgba(0,0,0,.1)}
.card.empty{border:1px dashed #ccc;background:transparent}
.card.s,.card.c{color:#000}
.card.h{color:#e53935}
.card.d{color:#1e88e5}
.card.club{color:#2e7d32}
.player{position:absolute;text-align:center;transform:translate(-50%,-50%)}
.player .badge{padding:6px 10px;border-radius:8px;font-size:11px;font-weight:bold;background:#fff;border:1px solid #ddd;min-width:50px}
.player.hero .badge{background:#000;color:#fff;border-color:#000}
.player.folded .badge{opacity:.4}
.player .action{font-size:9px;color:#666;margin-top:2px}
.player .cards{display:flex;gap:2px;justify-content:center;margin-bottom:4px}
.player .cards .card{width:24px;height:32px;font-size:9px}
.action-display{text-align:center;padding:16px;min-height:80px}
.action-display .street{display:flex;gap:12px;justify-content:center;margin-bottom:12px}
.action-display .street span{font-size:12px;color:#999}
.action-display .street span.active{color:#000;font-weight:bold}
.action-display .current{font-size:16px;font-weight:bold}
.action-display .current .pos{display:inline-block;padding:4px 10px;border-radius:6px;background:#eee;margin-right:8px}
.action-display .current .pos.hero{background:#000;color:#fff}
.controls{display:flex;justify-content:center;gap:16px;padding:16px;border-top:1px solid #eee}
.controls button{width:44px;height:44px;border-radius:50%;border:none;background:#fff;font-size:18px;cursor:pointer;border:1px solid #ddd}
.controls button.play{width:56px;height:56px;background:#000;color:#fff;font-size:20px;border:none}
.progress{height:4px;background:#eee;margin:0 16px}
.progress .bar{height:100%;background:#000;transition:width .3s}
.result{text-align:center;padding:16px;font-size:18px;font-weight:bold}
.result.win{color:#000}
.result.loss{color:#666}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h2>\(hand.stakes) - Hero: \(hand.heroPosition)</h2>
<div class="sub">\(hand.date.formatted(date: .abbreviated, time: .shortened))</div>
</div>
<div class="table-area">
<div class="table"></div>
<div class="board" id="board"></div>
<div class="pot" id="pot">$0</div>
<div id="players"></div>
</div>
<div class="action-display">
<div class="street" id="street">
<span class="active">Preflop</span><span>Flop</span><span>Turn</span><span>River</span>
</div>
<div class="current" id="current">Press play to start</div>
</div>
<div class="progress"><div class="bar" id="progress" style="width:0%"></div></div>
<div class="controls">
<button onclick="reset()">⏮</button>
<button onclick="prev()">⏪</button>
<button class="play" onclick="togglePlay()" id="playBtn">▶</button>
<button onclick="next()">⏩</button>
<button onclick="end()">⏭</button>
</div>
<div class="result" id="result"></div>
</div>
<script>
const positions=[
{id:0,name:'BTN',angle:270},{id:1,name:'SB',angle:310},{id:2,name:'BB',angle:350},
{id:3,name:'UTG',angle:30},{id:4,name:'UTG+1',angle:70},{id:5,name:'MP',angle:110},
{id:6,name:'MP+1',angle:150},{id:7,name:'HJ',angle:190},{id:8,name:'CO',angle:230}
];
const heroPos='\(hand.heroPosition)';
const holeCards=[\(holeCardsJS)];
const board=[\(boardJS)];
const actions=\(actionsJS);
const potSize=\(Int(hand.potSize));
const result=\(Int(hand.result));

let step=-1,playing=false,pot=0,players={},visibleBoard=0,timer=null;

function getSuitClass(c){const s=c.slice(-1);return s=='♠'?'s':s=='♥'?'h':s=='♦'?'d':'club'}
function renderCard(c,empty){
if(empty)return'<div class="card empty"></div>';
return'<div class="card '+getSuitClass(c)+'">'+c.slice(0,-1)+'<br>'+c.slice(-1)+'</div>';
}

function initPlayers(){
const area=document.querySelector('.table-area');
const w=area.offsetWidth,h=area.offsetHeight;
const cx=w/2,cy=h/2,rx=w*.38,ry=h*.32;
let html='';
positions.forEach(p=>{
const a=p.angle*Math.PI/180;
const x=cx+rx*Math.cos(a),y=cy+ry*Math.sin(a);
const isHero=p.name===heroPos;
players[p.name]={folded:false,action:null,bet:0};
html+='<div class="player'+(isHero?' hero':'')+'" id="p'+p.id+'" style="left:'+x+'px;top:'+y+'px">';
if(isHero)html+='<div class="cards">'+holeCards.map(c=>renderCard(c)).join('')+'</div>';
html+='<div class="badge">'+p.name+'</div><div class="action"></div></div>';
});
document.getElementById('players').innerHTML=html;
}

function updateBoard(){
let html='';
for(let i=0;i<5;i++)html+=renderCard(i<visibleBoard?board[i]:null,i>=visibleBoard);
document.getElementById('board').innerHTML=html;
}

function updateStreet(s){
const spans=document.querySelectorAll('.street span');
const streets=['Preflop','Flop','Turn','River'];
spans.forEach((sp,i)=>sp.className=streets[i]===s?'active':'');
}

function updatePlayer(pos,action,folded){
const p=positions.find(x=>x.name===pos);
if(!p)return;
const el=document.getElementById('p'+p.id);
if(folded)el.classList.add('folded');
el.querySelector('.action').textContent=action||'';
}

function showAction(a){
let html='<span class="pos'+(a.hero?' hero':'')+'">'+a.pos+'</span> '+a.action;
if(a.amount)html+=' $'+a.amount;
document.getElementById('current').innerHTML=html;
}

function updateProgress(){
const total=1+actions.length+(board.length>2?1:0)+(board.length>3?1:0)+(board.length>4?1:0);
const pct=Math.min(100,((step+1)/total)*100);
document.getElementById('progress').style.width=pct+'%';
}

function next(){
if(step<0){step=0;initPlayers();updateBoard();document.getElementById('pot').textContent='$0';pot=0;}
if(step<actions.length){
const a=actions[step];
// Check for street change - reveal board
if(step>0){
const prev=actions[step-1];
if(a.street!==prev.street){
if(a.street==='Flop'&&visibleBoard<3){visibleBoard=3;updateBoard();}
else if(a.street==='Turn'&&visibleBoard<4){visibleBoard=4;updateBoard();}
else if(a.street==='River'&&visibleBoard<5){visibleBoard=5;updateBoard();}
}
}
updateStreet(a.street);
showAction(a);
if(a.action==='Fold'){players[a.pos].folded=true;updatePlayer(a.pos,'Fold',true);}
else{updatePlayer(a.pos,a.action+(a.amount?' $'+a.amount:''),false);}
if(a.amount)pot+=a.amount;
document.getElementById('pot').textContent='$'+pot;
step++;
updateProgress();
return true;
}
// Reveal remaining board
if(visibleBoard<board.length){
if(visibleBoard<3&&board.length>=3){visibleBoard=3;updateBoard();updateStreet('Flop');updateProgress();return true;}
if(visibleBoard<4&&board.length>=4){visibleBoard=4;updateBoard();updateStreet('Turn');updateProgress();return true;}
if(visibleBoard<5&&board.length>=5){visibleBoard=5;updateBoard();updateStreet('River');updateProgress();return true;}
}
// Show result
document.getElementById('result').innerHTML=(result>=0?'+':'')+result;
document.getElementById('result').className='result '+(result>=0?'win':'loss');
updateProgress();
return false;
}

function prev(){
if(step<=0)return;
step=Math.max(-1,step-2);
reset();
for(let i=0;i<=step;i++)next();
}

function reset(){
step=-1;pot=0;visibleBoard=0;
Object.keys(players).forEach(k=>players[k]={folded:false,action:null,bet:0});
document.getElementById('current').textContent='Press play to start';
document.getElementById('pot').textContent='$0';
document.getElementById('result').textContent='';
document.getElementById('progress').style.width='0%';
updateStreet('Preflop');
initPlayers();
updateBoard();
}

function end(){
stop();
reset();
while(next()){}
}

function togglePlay(){
if(playing)stop();
else{playing=true;document.getElementById('playBtn').textContent='⏸';play();}
}

function play(){
if(!playing)return;
if(next())timer=setTimeout(play,1200);
else stop();
}

function stop(){
playing=false;
document.getElementById('playBtn').textContent='▶';
if(timer)clearTimeout(timer);
}

window.onload=()=>{initPlayers();updateBoard();};
window.onresize=()=>{initPlayers();};
</script>
</body>
</html>
"""
    }

    private func getSuitSymbol(_ suit: Suit) -> String {
        suit.symbol
    }

}

// MARK: - Replay Player View

struct ReplayPlayerView: View {
    let player: PlayerState
    let showCards: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Cards
            if showCards && !player.cards.isEmpty {
                HStack(spacing: 2) {
                    ForEach(player.cards) { card in
                        MiniCardView(card: card)
                            .scaleEffect(0.85)
                    }
                }
            }

            // Player badge
            VStack(spacing: 2) {
                Text(player.position.shortName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(player.isHero ? .white : (player.isFolded ? .gray : .black))

                if let action = player.lastAction {
                    Text(action.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(player.isHero ? .white.opacity(0.8) : .gray)
                }

                if player.currentBet > 0 {
                    Text("$\(Int(player.currentBet))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(player.isHero ? .white : .black)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(player.isHero ? Color.black : (player.isFolded ? Color.gray.opacity(0.15) : Color.white))
                    .shadow(color: .black.opacity(0.1), radius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(player.isHero ? Color.clear : Color.black.opacity(0.2), lineWidth: 1)
            )
            .opacity(player.isFolded ? 0.5 : 1)
        }
    }
}

#Preview {
    ReplayAnimationView(hand: PokerHand(
        stakes: "1/2 NL",
        heroPosition: "BTN",
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)],
        board: [
            Card(rank: .queen, suit: .spades),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .diamonds),
            Card(rank: .two, suit: .clubs),
            Card(rank: .seven, suit: .hearts)
        ],
        actions: [
            HandAction(street: .preflop, position: "UTG", action: .raise, amount: 10),
            HandAction(street: .preflop, position: "BTN", action: .call, amount: 10, isHero: true),
            HandAction(street: .preflop, position: "BB", action: .fold),
            HandAction(street: .flop, position: "UTG", action: .bet, amount: 15),
            HandAction(street: .flop, position: "BTN", action: .raise, amount: 45, isHero: true),
            HandAction(street: .flop, position: "UTG", action: .call, amount: 30),
            HandAction(street: .turn, position: "UTG", action: .check),
            HandAction(street: .turn, position: "BTN", action: .bet, amount: 80, isHero: true),
            HandAction(street: .turn, position: "UTG", action: .fold)
        ],
        potSize: 190,
        result: 190,
        notes: "Flopped the nuts!"
    ))
}
