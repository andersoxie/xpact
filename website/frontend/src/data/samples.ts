// Example documents for the validator. Each one shows a different thing XPact checks.

export interface Sample {
  id: string;
  label: string;
  expect: "accepted" | "rejected";
  xml: string;
}

export const SAMPLES: Sample[] = [
  {
    id: "catalog",
    label: "Valid: book catalog",
    expect: "accepted",
    xml: `<?xml version="1.0" encoding="UTF-8"?>
<!-- A small, well-formed document -->
<catalog>
  <book id="bk101" lang="en">
    <author>Gambardella, Matthew</author>
    <title>XML Developer's Guide</title>
    <price currency="EUR">44.95</price>
  </book>
  <book id="bk102" lang="sv">
    <author>Ralls, Kim</author>
    <title>Midnight Rain</title>
    <price currency="SEK">59.00</price>
  </book>
</catalog>
`,
  },
  {
    id: "entities",
    label: "Valid: DTD and entities",
    expect: "accepted",
    xml: `<?xml version="1.0"?>
<!DOCTYPE note [
  <!ENTITY company "XPact &amp; Co">
  <!ATTLIST note priority (low|high) "low">
]>
<note>
  <from>&company;</from>
  <body>Characters: &lt; &gt; &#x00E9; &#233;</body>
  <![CDATA[ <not-markup> & raw text ]]>
  <?render mode="fast"?>
</note>
`,
  },
  {
    id: "mismatch",
    label: "Invalid: mismatched tag",
    expect: "rejected",
    xml: `<order>
  <item>Keyboard</item>
  <item>Mouse</itm>
</order>
`,
  },
  {
    id: "attribute",
    label: "Invalid: duplicate attribute",
    expect: "rejected",
    xml: `<user id="1" name="Ada" id="2"/>
`,
  },
  {
    id: "junk",
    label: "Invalid: text after the root",
    expect: "rejected",
    xml: `<root/>
trailing text is not allowed
`,
  },
  {
    id: "unclosed",
    label: "Invalid: unclosed element",
    expect: "rejected",
    xml: `<config>
  <setting name="debug">true</setting>
`,
  },
];
