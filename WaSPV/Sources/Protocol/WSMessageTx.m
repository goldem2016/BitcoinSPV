//
//  WSMessageTx.m
//  WaSPV
//
//  Created by Davide De Rosa on 02/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of WaSPV.
//
//  WaSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  WaSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with WaSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import "WSErrors.h"

#import "WSMessageTx.h"
#import "WSTransaction.h"

@interface WSMessageTx ()

@property (nonatomic, strong) WSSignedTransaction *transaction;

- (instancetype)initWithTransaction:(WSSignedTransaction *)transaction;

@end

@implementation WSMessageTx

+ (instancetype)messageWithTransaction:(WSSignedTransaction *)transaction
{
    return [[self alloc] initWithTransaction:transaction];
}

- (instancetype)initWithTransaction:(WSSignedTransaction *)transaction
{
    WSExceptionCheckIllegal(transaction != nil, @"Nil transaction");
    
    if ((self = [super init])) {
        self.transaction = transaction;
    }
    return self;
}

#pragma mark WSMessage

- (NSString *)messageType
{
    return WSMessageType_TX;
}

- (NSString *)payloadDescriptionWithIndent:(NSUInteger)indent
{
    return [self.transaction descriptionWithIndent:indent];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [self.transaction appendToMutableBuffer:buffer];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self.transaction estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if ((self = [super initWithOriginalPayload:buffer])) {
        self.transaction = [[WSSignedTransaction alloc] initWithBuffer:buffer from:from available:available error:error];
    }
    return self;
}

@end