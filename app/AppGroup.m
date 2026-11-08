//
//  AppGroup.m
//  iSH
//
//  Created by Theodore Dubois on 2/28/20.
//

#import "AppGroup.h"
#import <Foundation/Foundation.h>
#import <mach-o/ldsyms.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>

#define CSMAGIC_EMBEDDED_SIGNATURE 0xfade0cc0
#define CSMAGIC_EMBEDDED_ENTITLEMENTS 0xfade7171

struct cs_blob_index {
    uint32_t type;
    uint32_t offset;
};

struct cs_superblob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
    struct cs_blob_index index[];
};

struct cs_entitlements {
    uint32_t magic;
    uint32_t length;
    char entitlements[];
};

static NSDictionary *AppEntitlements(void) {
    static NSDictionary *entitlements;
    if (entitlements != nil)
        return entitlements;
    
    // Inspired by codesign.c in Darwin sources for Security.framework
    
    const struct mach_header_64 *header = &_mh_execute_header;
    
    // Simulator executables have fake entitlements in the code signature. The real entitlements can be found in an __entitlements section.
    size_t entitlements_size;
    char *entitlements_data = (char *) getsectiondata(header, "__TEXT", "__entitlements", &entitlements_size);
    if (entitlements_data != NULL) {
        NSData *data = [NSData dataWithBytesNoCopy:entitlements_data
                                            length:entitlements_size
                                      freeWhenDone:NO];
        return entitlements = [NSPropertyListSerialization propertyListWithData:data
                                                                        options:NSPropertyListImmutable
                                                                         format:nil
                                                                          error:nil];
    }
    
    // Find the LC_CODE_SIGNATURE
    struct load_command *lc = (void *) (header + 1);
    struct linkedit_data_command *cs_lc = NULL;
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_CODE_SIGNATURE) {
            cs_lc = (void *) lc;
            break;
        }
        lc = (void *) ((char *) lc + lc->cmdsize);
    }
    if (cs_lc == NULL)
        return nil;

    // Read the code signature off disk, as it's apparently not loaded into memory
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:NSBundle.mainBundle.executableURL error:nil];
    if (fileHandle == nil)
        return nil;
    [fileHandle seekToFileOffset:cs_lc->dataoff];
    NSData *csData = [fileHandle readDataOfLength:cs_lc->datasize];
    [fileHandle closeFile];
    const struct cs_superblob *cs = csData.bytes;
    if (ntohl(cs->magic) != CSMAGIC_EMBEDDED_SIGNATURE)
        return nil;
    
    // Find the entitlements in the code signature
    NSData *entitlementsData = nil;
    for (uint32_t i = 0; i < ntohl(cs->count); i++) {
        struct cs_entitlements *ents = (void *) ((char *) cs + ntohl(cs->index[i].offset));
        if (ntohl(ents->magic) == CSMAGIC_EMBEDDED_ENTITLEMENTS) {
            entitlementsData = [NSData dataWithBytes:ents->entitlements
                                              length:ntohl(ents->length) - offsetof(struct cs_entitlements, entitlements)];
        }
    }
    if (entitlementsData == nil)
        return nil;
    
    return entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData
                                                                    options:NSPropertyListImmutable
                                                                     format:nil
                                                                      error:nil];
}

NSArray<NSString *> *CurrentAppGroups(void) {
    NSArray<NSString *> *groups = AppEntitlements()[@"com.apple.security.application-groups"];
    return [groups isKindOfClass:NSArray.class] ? groups : @[];
}

NSURL *ContainerURL(void) {
    // LiveContainer intentionally does not apply guest-app entitlements. A
    // TrollStore-signed build can also be installed without a provisioned App
    // Group. Passing nil or an unavailable group here made the root filesystem
    // URL nil and caused a crash before the first screen was shown.
    for (NSString *appGroup in CurrentAppGroups()) {
        if (![appGroup isKindOfClass:NSString.class] || appGroup.length == 0)
            continue;
        NSURL *url = [NSFileManager.defaultManager
                      containerURLForSecurityApplicationGroupIdentifier:appGroup];
        if (url != nil)
            return url;
    }

    // Keep the filesystem private to this app when an App Group is not
    // available. This works in LiveContainer and preserves existing data for
    // normal installations that do have the App Group entitlement.
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *fallback = [manager URLsForDirectory:NSApplicationSupportDirectory
                                       inDomains:NSUserDomainMask].firstObject;
    fallback = [fallback URLByAppendingPathComponent:@"iShell" isDirectory:YES];
    [manager createDirectoryAtURL:fallback
       withIntermediateDirectories:YES
                        attributes:nil
                             error:nil];
    return fallback;
}
