module PlayingCards

using Random: randperm
import Random: shuffle!

import Base

# Suits
export ♣, ♠, ♡, ♢ # aliases

# Card, and Suit
export Card, Suit

# Card properties
export suit, rank, high_value, low_value, color

# Lists of all ranks / suits
export ranks, suits

# Deck & deck-related methods
export Deck, shuffle!, full_deck, ordered_deck

#####
##### Types
#####

"""
Encode a suit as a 2-bit value (low bits of a `UInt8`):
- 0 = ♣ (clubs)
- 1 = ♢ (diamonds)
- 2 = ♡ (hearts)
- 3 = ♠ (spades)
The suits have global constant bindings: `♣`, `♢`, `♡`, `♠`.
"""
struct Suit
    i::UInt8
    Suit(s::Integer) = 0 ≤ s ≤ 3 ? new(s) :
        throw(ArgumentError("invalid suit number: $s"))
end

char(s::Suit) = Char(0x2663-s.i)
Base.string(s::Suit) = string(char(s))
Base.show(io::IO, s::Suit) = print(io, char(s))

"""
Encode a playing card as a 6-bit integer (low bits of a `UInt8`):
- low bits represent rank from 0 to 15
- high bits represent suit (♣, ♢, ♡ or ♠)
Ranks are assigned as follows:
- numbered cards (2 to 10) have rank equal to their number
- jacks, queens and kings have ranks 11, 12 and 13
- there are low and high aces with ranks 1 and 14
- there are low and high jokers with ranks 0 and 15
This allows any of the standard orderings of cards ranks to be
achieved simply by choosing which aces or which jokers to use.
There are a total of 64 possible card values with this scheme,
represented by `UInt8` values `0x00` through `0x3f`.
"""
struct Card
    value::UInt8
end

function Card(r::Integer, s::Integer)
    1 ≤ r ≤ 13 || throw(ArgumentError("invalid card rank: $r"))
    return Card(((s << 4) % UInt8) | (r % UInt8))
end
Card(r::Integer, s::Suit) = Card(r, s.i)

suit(c::Card) = Suit((0x30 & c.value) >>> 4)
rank(c::Card) = (c.value & 0x0f) % Int8

const ♣ = Suit(0)
const ♢ = Suit(1)
const ♡ = Suit(2)
const ♠ = Suit(3)

bit(c::Card) = one(UInt64) << c.value
bits(s::Suit) = UInt64(0xffff) << 16(s.i)

# Allow constructing cards with, e.g., `3♡`
Base.:*(r::Integer, s::Suit) = Card(r, s)

function Base.show(io::IO, c::Card)
    r = rank(c)
    if 1 ≤ r ≤ 14
        if r == 10
            print(io, 'T')
        elseif r == 1
            print(io, 'A')
        else
            print(io, "1234567890JQKA"[r])
        end
    else
        print(io, '\U1f0cf')
    end
    print(io, suit(c))
end

# And for face cards:
# Not to be confused with
# ♡, ♡
# ♢, ♢
for s in "♣♢♡♠", (f,typ) in zip((:J,:Q,:K,:A),(11,12,13,1))
    ss, sc = Symbol(s), Symbol("$f$s")
    @eval (export $sc; const $sc = Card($typ,$ss))
end
for s in "♣♢♡♠"
    ss, sc = Symbol(s), Symbol("T$s")
    @eval (export $sc; const $sc = Card(10,$ss))
end

#####
##### Methods
#####

function rank_string(r::Int8)
    2 ≤ r ≤ 9 && return "$(r)"
    r == 10 && return "T"
    r == 11 && return "J"
    r == 12 && return "Q"
    r == 13 && return "K"
    r == 1 && return "A"
    error("Unrecognized rank string")
end

Base.string(card::Card) = rank_string(rank(card))*string(suit(card))

# TODO: define Base.isless ? Problem: high Ace vs. low Ace

"""
    high_value(::Card)
    high_value(::Rank)

The high rank value. For example:
 - `Rank(1)` -> 14 (use [`low_value`](@ref) for the low Ace value.)
 - `Rank(5)` -> 5
"""
high_value(c::Card) = rank(c) == 1 ? 14 : rank(c)

"""
    low_value(::Card)
    low_value(::Rank)

The low rank value. For example:
 - `Rank(1)` -> 1 (use [`high_value`](@ref) for the high Ace value.)
 - `Rank(5)` -> 5
"""
low_value(c::Card) = rank(c)

"""
    color(::Card)

A `Symbol` (`:red`, or `:black`) indicating
the color of the suit or card.
"""
function color(s::Suit)
    if s == ♣ || s == ♠
        return :black
    elseif s == ♡ || s == ♢
        return :red
    else
        error("Card doesn't have color")
    end
end
color(card::Card) = color(suit(card))

#####
##### Full deck/suit/rank methods
#####

"""
    ranks

A Tuple of ranks `1:13`.
"""
ranks() = 1:13

"""
    suits

A Tuple of all suits
"""
suits() = (♣, ♠, ♡, ♢)

"""
    full_deck

A vector of a cards
containing a full deck
"""
full_deck() = Card[Card(r,s) for s in suits() for r in ranks()]


#### Deck

"""
    Deck

Deck of cards (backed by a `Vector{Card}`)
"""
struct Deck{C <: Vector}
    cards::C
end

Base.length(deck::Deck) = length(deck.cards)

Base.iterate(deck::Deck, state=1) = Base.iterate(deck.cards, state)

function Base.show(io::IO, deck::Deck)
    for (i, card) in enumerate(deck)
        Base.show(io, card)
        if mod(i, 13) == 0
            println(io)
        else
            print(io, " ")
        end
    end
end

"""
    pop!(deck::Deck, n::Int = 1)
    pop!(deck::Deck, card::Card)

Remove `n` cards from the `deck`.
or
Remove `card` from the `deck`.
"""
Base.pop!(deck::Deck, n::Integer = 1) = ntuple(i->pop!(deck.cards), n)
function Base.pop!(deck::Deck, card::Card)
    L0 = length(deck)
    filter!(x -> x ≠ card, deck.cards)
    L0 == length(deck)+1 || error("Could not pop $(card) from deck.")
    return card
end

"""
    ordered_deck

An ordered `Deck` of cards.
"""
ordered_deck() = Deck(full_deck())

"""
    shuffle!

Shuffle the deck! `shuffle!` uses
`Random.randperm` to shuffle the deck.
"""
function shuffle!(deck::Deck)
    deck.cards .= deck.cards[randperm(length(deck.cards))]
    nothing
end

end # module
