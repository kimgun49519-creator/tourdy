/* One atomic native JSON envelope; the app's original state format is retained. */
function createFileRecords(plugin, initialRaw, legacy = {}) {
  let expected = initialRaw;
  let records;
  if (initialRaw === null) records = {...legacy};
  else {
    const envelope = JSON.parse(initialRaw);
    if (envelope?.format !== 1 || !envelope.records || Array.isArray(envelope.records) || typeof envelope.records !== 'object') throw Error('Invalid native records');
    if (!Object.entries(envelope.records).every(([key,value]) => /^studyplanner\.v[12](?:\.(?:lastGood|damaged))?$/.test(key) && typeof value === 'string')) throw Error('Invalid native record entries');
    records = {...envelope.records};
  }
  const storage = {
    getItem:key => records[key] ?? null,
    setItem(){throw Error('Native record writes must await file persistence');}
  };
  async function commit(changes) {
    const next = {...records,...changes};
    const raw = JSON.stringify({format:1,records:next});
    await plugin.commit({expected, data:raw});
    records = next;
    expected = raw;
  }
  return {storage,commit};
}
module.exports = {createFileRecords};
