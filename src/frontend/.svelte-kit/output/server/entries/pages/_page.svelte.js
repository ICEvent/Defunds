import { c as create_ssr_component, e as escape, d as each } from "../../chunks/ssr.js";
import { HttpAgent, Actor } from "@dfinity/agent";
import { b as building } from "../../chunks/environment.js";
const index = "";
const idlFactory = ({ IDL }) => {
  const Result = IDL.Variant({ "ok": IDL.Nat, "err": IDL.Text });
  const Donation = IDL.Record({
    "currency": IDL.Text,
    "timestamp": IDL.Int,
    "amount": IDL.Nat,
    "donor": IDL.Principal
  });
  const Time = IDL.Int;
  return IDL.Service({
    "donate": IDL.Func([IDL.Nat, IDL.Text], [Result], []),
    "getDoantions": IDL.Func([], [IDL.Vec(Donation)], ["query"]),
    "getDonationHistory": IDL.Func(
      [IDL.Nat, IDL.Nat, IDL.Opt(Time), IDL.Opt(Time)],
      [IDL.Vec(Donation)],
      ["query"]
    ),
    "getDonorHistory": IDL.Func(
      [IDL.Principal],
      [IDL.Vec(Donation)],
      ["query"]
    )
  });
};
const canisterId = "be2us-64aaa-aaaaa-qaabq-cai";
const createActor = (canisterId2, options = {}) => {
  const agent = options.agent || new HttpAgent({ ...options.agentOptions });
  if (options.agent && options.agentOptions) {
    console.warn(
      "Detected both agent and agentOptions passed to createActor. Ignoring agentOptions and proceeding with the provided agent."
    );
  }
  {
    agent.fetchRootKey().catch((err) => {
      console.warn(
        "Unable to fetch root key. Check to ensure that your local replica is running"
      );
      console.error(err);
    });
  }
  return Actor.createActor(idlFactory, {
    agent,
    canisterId: canisterId2,
    ...options.actorOptions
  });
};
function dummyActor() {
  return new Proxy({}, { get() {
    throw new Error("Canister invoked while building");
  } });
}
const buildingOrTesting = building || process.env.NODE_ENV === "test";
buildingOrTesting ? dummyActor() : createActor(canisterId);
const _page_svelte_svelte_type_style_lang = "";
const css = {
  code: "header.svelte-5yl6aj{text-align:center;margin-bottom:2rem}.content.svelte-5yl6aj{display:flex;justify-content:space-between}.applications.svelte-5yl6aj{width:48%}.donation-history.svelte-5yl6aj{width:48%}.card.svelte-5yl6aj{border:1px solid #ccc;padding:1rem;margin-bottom:1rem}.history-item.svelte-5yl6aj{border:1px solid #ccc;padding:1rem;margin-bottom:1rem}",
  map: null
};
let totalDonations = 0;
const Page = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  let applications = [
    {
      id: 1,
      name: "Application 1",
      description: "Description for Application 1"
    },
    {
      id: 2,
      name: "Application 2",
      description: "Description for Application 2"
    }
  ];
  let donationHistory = [
    { id: 1, amount: 100, date: "2023-05-01" },
    { id: 2, amount: 200, date: "2023-04-15" }
  ];
  $$result.css.add(css);
  return `<main><header class="svelte-5yl6aj"><h1 data-svelte-h="svelte-1p5tpto">Know your donation</h1> <p>Treasury: ${escape(totalDonations)}</p></header> <div class="content svelte-5yl6aj"><div class="donation-history svelte-5yl6aj"><h2 data-svelte-h="svelte-n1jmyw">Donation History</h2> ${each(donationHistory, (donation) => {
    return `<div class="history-item svelte-5yl6aj"><p>Amount: ${escape(donation.amount)}</p> <p>Date: ${escape(donation.date)}</p> </div>`;
  })}</div> <div class="applications svelte-5yl6aj"><h2 data-svelte-h="svelte-1e734jh">Applications</h2> ${each(applications, (app) => {
    return `<div class="card svelte-5yl6aj"><h3>${escape(app.name)}</h3> <p>${escape(app.description)}</p> <button data-svelte-h="svelte-4f4o6u">Vote</button> </div>`;
  })}</div></div> </main>`;
});
export {
  Page as default
};
