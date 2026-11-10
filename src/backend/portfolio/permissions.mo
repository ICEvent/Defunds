import Array "mo:base/Array";
import Principal "mo:base/Principal";
module {
  // Callers supply current membership; voting weights and public visibility
  // deliberately do not enter the portfolio authorization decision.
  public func canAccess(caller : Principal, creator : Principal, members : [Principal], managers : [Principal], write : Bool) : Bool {
    if (Principal.isAnonymous(caller)) return false;
    if (caller == creator) return true;
    if (Array.find<Principal>(members, func(p) { p == caller }) == null) return false;
    not write or Array.find<Principal>(managers, func(p) { p == caller }) != null
  };
}
