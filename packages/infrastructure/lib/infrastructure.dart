/// LifeFlow infrastructure (scaffold skeleton, P01). Drift database,
/// repositories, outbox/sync and platform adapters are implemented in P01+
/// (they implement ports defined in domain/application). See
/// docs/architecture/repository-structure.md and docs/data/.
///
/// The S-02 spike (migrations + FTS5 + encryption) proved these mechanisms;
/// its throwaway code is on the spike branches, its results in
/// docs/spikes/spike-results.md. P01 builds the real database here.
library infrastructure;
