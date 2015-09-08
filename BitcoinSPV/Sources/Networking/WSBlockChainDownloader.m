//
//  WSBlockChainDownloader.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/08/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of BitcoinSPV.
//
//  BitcoinSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  BitcoinSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with BitcoinSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import "WSBlockChainDownloader.h"
#import "WSBlockStore.h"
#import "WSBlockChain.h"
#import "WSBlockHeader.h"
#import "WSWallet.h"
#import "WSHDWallet.h"
#import "WSConnectionPool.h"
#import "WSLogging.h"
#import "WSErrors.h"

@interface WSBlockChainDownloader ()

// configuration
@property (nonatomic, strong) id<WSBlockStore> store;
@property (nonatomic, strong) WSBlockChain *blockChain;
@property (nonatomic, strong) id<WSSynchronizableWallet> wallet;
@property (nonatomic, assign) uint32_t fastCatchUpTimestamp;
@property (nonatomic, assign) BOOL shouldDownloadBlocks;
@property (nonatomic, assign) BOOL needsBloomFiltering;

// state
@property (nonatomic, strong) WSPeer *downloadPeer;
@property (nonatomic, strong) NSCountedSet *pendingBlockIds;
@property (nonatomic, strong) NSMutableOrderedSet *processingBlockIds;
@property (nonatomic, assign) NSUInteger filteredBlockCount;
@property (nonatomic, strong) WSBlockLocator *startingBlockChainLocator;

- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers;
//- (void)aheadRequestOnReceivedHeaders:(NSArray *)headers;
//- (void)aheadRequestOnReceivedBlockHashes:(NSArray *)hashes;
//- (void)requestHeadersWithLocator:(WSBlockLocator *)locator;
//- (void)requestBlocksWithLocator:(WSBlockLocator *)locator;
//- (void)addBlockHeaders:(NSArray *)headers; // WSBlockHeader

@end

@implementation WSBlockChainDownloader

- (instancetype)initWithStore:(id<WSBlockStore>)store headersOnly:(BOOL)headersOnly
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = 0;

        self.shouldDownloadBlocks = !headersOnly;
        self.needsBloomFiltering = NO;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store fastCatchUpTimestamp:(uint32_t)fastCatchUpTimestamp
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = nil;
        self.fastCatchUpTimestamp = fastCatchUpTimestamp;

        self.shouldDownloadBlocks = NO;
        self.needsBloomFiltering = NO;
    }
    return self;
}

- (instancetype)initWithStore:(id<WSBlockStore>)store wallet:(id<WSSynchronizableWallet>)wallet
{
    if ((self = [super init])) {
        self.store = store;
        self.blockChain = [[WSBlockChain alloc] initWithStore:self.store];
        self.wallet = wallet;
        self.fastCatchUpTimestamp = [self.wallet earliestKeyTimestamp];

        self.shouldDownloadBlocks = NO;
        self.needsBloomFiltering = YES;
    }
    return self;
}

- (id<WSParameters>)parameters
{
    return [self.store parameters];
}

#pragma mark WSPeerGroupDownloadDelegate

- (void)peerGroup:(WSPeerGroup *)peerGroup didStartDownloadWithConnectedPeers:(NSArray *)connectedPeers
{
    self.downloadPeer = [self bestPeerAmongPeers:connectedPeers];
    if (!self.downloadPeer) {
        DDLogInfo(@"Delayed download until peer selection");
        return;
    }
    DDLogInfo(@"Peer %@ is new download peer", self.downloadPeer);

#warning TODO: download, request blocks
}

- (void)peerGroupDidStopDownload:(WSPeerGroup *)peerGroup pool:(WSConnectionPool *)pool
{
    if (self.downloadPeer) {
        [pool closeConnectionForProcessor:self.downloadPeer
                                    error:WSErrorMake(WSErrorCodePeerGroupStop, @"Download stopped")];
    }
    self.downloadPeer = nil;
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peerDidConnect:(WSPeer *)peer
{
    if (!self.downloadPeer) {
        self.downloadPeer = peer;
        DDLogInfo(@"Peer %@ connected, is new download peer", self.downloadPeer);

#warning TODO: download, request blocks
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didDisconnectWithError:(NSError *)error connectedPeers:(NSArray *)connectedPeers
{
    if (peer == self.downloadPeer) {
        DDLogDebug(@"Peer %@ disconnected, was download peer", peer);

        self.downloadPeer = [self bestPeerAmongPeers:connectedPeers];
        if (!self.downloadPeer) {
            DDLogError(@"No more peers for download (%@)", error);
            return;
        }
        DDLogDebug(@"Switched to next best download peer %@", self.downloadPeer);

#warning TODO: download, request blocks
    }
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveHeader:(WSBlockHeader *)header
{
#warning TODO: download, handle header
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveBlock:(WSBlock *)block
{
#warning TODO: download, handle block
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveFilteredBlock:(WSFilteredBlock *)filteredBlock withTransactions:(NSOrderedSet *)transactions
{
#warning TODO: download, handle filtered block
}

- (void)peerGroup:(WSPeerGroup *)peerGroup peer:(WSPeer *)peer didReceiveTransaction:(WSSignedTransaction *)transaction
{
#warning TODO: download, handle transaction
}

#pragma mark Helpers

- (WSPeer *)bestPeerAmongPeers:(NSArray *)peers
{
    WSPeer *bestPeer = nil;
    for (WSPeer *peer in peers) {

        // double check connection status
        if (peer.peerStatus != WSPeerStatusConnected) {
            continue;
        }

        // max chain height or min ping
        if (!bestPeer ||
            (peer.lastBlockHeight > bestPeer.lastBlockHeight) ||
            ((peer.lastBlockHeight == bestPeer.lastBlockHeight) && (peer.connectionTime < bestPeer.connectionTime))) {

            bestPeer = peer;
        }
    }
    return bestPeer;
}

@end
