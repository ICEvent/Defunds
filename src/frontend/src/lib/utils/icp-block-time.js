import { Actor } from '@dfinity/agent';

// Read-only projection of the ICP ledger Candid interface. Block records only
// decode the timestamp needed here; archive callbacks use the same projection.
function types(IDL) {
    const request = IDL.Record({ start: IDL.Nat64, length: IDL.Nat64 });
    const block = IDL.Record({ timestamp: IDL.Record({ timestamp_nanos: IDL.Nat64 }) });
    const error = IDL.Variant({
        BadFirstBlockIndex: IDL.Record({ requested_index: IDL.Nat64, first_valid_index: IDL.Nat64 }),
        Other: IDL.Record({ error_code: IDL.Nat64, error_message: IDL.Text })
    });
    const archiveResult = IDL.Variant({ Ok: IDL.Record({ blocks: IDL.Vec(block) }), Err: error });
    return { request, block, archiveResult };
}

export function createBlockTimeReader(agent, canisterId) {
    const ledger = Actor.createActor(({ IDL }) => {
        const { request, block, archiveResult } = types(IDL);
        return IDL.Service({ query_blocks: IDL.Func([request], [IDL.Record({
            blocks: IDL.Vec(block),
            first_block_index: IDL.Nat64,
            archived_blocks: IDL.Vec(IDL.Record({
                start: IDL.Nat64, length: IDL.Nat64,
                callback: IDL.Func([request], [archiveResult], ['query'])
            }))
        })], ['query']) });
    }, { agent, canisterId });
    const queryArchive = ([archiveId, method], request) => {
        const archive = Actor.createActor(({ IDL }) => {
            const { request: args, archiveResult } = types(IDL);
            return IDL.Service({ [method]: IDL.Func([args], [archiveResult], ['query']) });
        }, { agent, canisterId: archiveId });
        return archive[method](request);
    };
    return { ledger, queryArchive };
}
