// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Embedded hinting parity tests ported from `fontations-reference/skrifa`.
///
/// The fonts are sourced from `fontations-reference/font-test-data` and embedded
/// as base64 strings.
const TAG_HDMX_HINT_PARITY : UInt = 0x68646D78 // "hdmx"

///|
const TAG_MAXP_HINT_PARITY : UInt = 0x6D617870 // "maxp"

///|
fn hint_parity_read_u16_be(view : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_int()
    let b1 = view.at(offset + 1).to_int()
    Some((b0 << 8) | b1)
  }
}

///|
fn hint_parity_read_u32_be(view : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset + 4 > view.length() {
    None
  } else {
    let b0 = view.at(offset).to_uint()
    let b1 = view.at(offset + 1).to_uint()
    let b2 = view.at(offset + 2).to_uint()
    let b3 = view.at(offset + 3).to_uint()
    Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
}

///|
fn hint_parity_num_glyphs(font : @moon_skrifa.FontRef) -> Int? {
  match font.table(TAG_MAXP_HINT_PARITY) {
    None => None
    Some(maxp) => hint_parity_read_u16_be(maxp, 4)
  }
}

///|
fn hint_parity_hdmx_width(
  font : @moon_skrifa.FontRef,
  ppem : Int,
  gid : @moon_skrifa.GlyphId,
) -> Int? {
  let num_glyphs = hint_parity_num_glyphs(font).unwrap_or(0)
  if num_glyphs <= 0 {
    return None
  }
  let hdmx = match font.table(TAG_HDMX_HINT_PARITY) {
    None => return None
    Some(v) => v
  }
  if hdmx.length() < 8 {
    return None
  }
  let num_records = hint_parity_read_u16_be(hdmx, 2).unwrap_or(0)
  let rec_size = hint_parity_read_u32_be(hdmx, 4)
    .unwrap_or(0)
    .to_uint64()
    .to_int()
  if rec_size <= 0 {
    return None
  }
  let base = 8
  for i in 0..<num_records {
    let off = base + i * rec_size
    if off + rec_size > hdmx.length() {
      break
    }
    if off + 2 + num_glyphs > hdmx.length() {
      break
    }
    let pix = hdmx.at(off).to_int()
    if pix == ppem {
      let widths_off = off + 2
      let idx = gid.to_uint64().to_int()
      if idx < 0 || idx >= num_glyphs {
        return None
      }
      return Some(hdmx.at(widths_off + idx).to_int())
    }
  }
  None
}

///|
fn hint_parity_hint_error_tag(e : HintError) -> String {
  match e {
    HintError::Unsupported => "Unsupported"
    HintError::UnexpectedEndOfBytecode => "UnexpectedEndOfBytecode"
    HintError::UnhandledOpcode(op, pc) =>
      "UnhandledOpcode op=" + op.to_string() + " pc=" + pc.to_string()
    HintError::DefinitionInGlyphProgram => "DefinitionInGlyphProgram"
    HintError::NestedDefinition => "NestedDefinition"
    HintError::DefinitionTooLarge => "DefinitionTooLarge"
    HintError::TooManyDefinitions => "TooManyDefinitions"
    HintError::InvalidDefinition(idx) =>
      "InvalidDefinition idx=" + idx.to_string()
    HintError::ValueStackOverflow => "ValueStackOverflow"
    HintError::ValueStackUnderflow => "ValueStackUnderflow"
    HintError::CallStackOverflow => "CallStackOverflow"
    HintError::CallStackUnderflow => "CallStackUnderflow"
    HintError::InvalidStackValue(v) => "InvalidStackValue v=" + v.to_string()
    HintError::InvalidPointIndex(i) => "InvalidPointIndex i=" + i.to_string()
    HintError::InvalidPointRange(a, b) =>
      "InvalidPointRange " + a.to_string() + "," + b.to_string()
    HintError::InvalidContourIndex(i) =>
      "InvalidContourIndex i=" + i.to_string()
    HintError::InvalidCvtIndex(i) => "InvalidCvtIndex i=" + i.to_string()
    HintError::InvalidStorageIndex(i) =>
      "InvalidStorageIndex i=" + i.to_string()
    HintError::DivideByZero => "DivideByZero"
    HintError::InvalidZoneIndex(i) => "InvalidZoneIndex i=" + i.to_string()
    HintError::NegativeLoopCounter => "NegativeLoopCounter"
    HintError::InvalidJump => "InvalidJump"
    HintError::ExceededExecutionBudget => "ExceededExecutionBudget"
  }
}

///|
fn hint_parity_font_tinos_subset_b64() -> String {
  "AAEAAAATAQAABAAwR0RFRgAQAAcAACrsAAAAFkdQT1N/a59vAAArBAAAAIpHU1VCpgeo8wAAK5AAAAAsT1MvMnp2s0AAAAfcAAAA" +
  "YFZETVhOI2iCAAAIPAAAEZRjbWFwAJ4BZQAAGvgAAABMY3Z0IF4bUjEAACaIAAAC0mZwZ202CxYMAAAbRAAAB7RnYXNwABoAJwAA" +
  "KtwAAAAQZ2x5ZnOjiUEAAAE8AAAF+GhkbXg6qnzJAAAZ0AAAAShoZWFkCFCfSQAAB2QAAAA2aGhlYQ1bA9YAAAe4AAAAJGhtdHge" +
  "JwEWAAAHnAAAABxsb2NhA/cFqgAAB1QAAAAQbWF4cAOUBdUAAAc0AAAAIG5hbWUasTSlAAApXAAAAWBwb3N0/yQAZAAAKrwAAAAg" +
  "cHJlcAFnlQYAACL4AAADkAACAH8DXALFBT0AAwAHAP9AswUEAQAEAAgJBwYCAQoCBAADtgkBpgkBaQkBWQkBSwkBBAkB9gkB5gkB" +
  "1gkBqQkBmQkBiQkBeQkBNgkBJgkBFgkB6QkBxgkBdAkBZgkBUgkBAUAJATAJASAJARQJAQQJATrACQG0CQGkCQGACQFwCQFkCQFU" +
  "CQEkCQEACQH0CQHkCQHUCQGkCQGUCQFkCQFACQE0CQEkCQEUCQHECQGACQFwCQECYAkBUAkBTwkBLwkBAAkBXV1dXV1fXV1dcXFx" +
  "cXFxcXFxcXJycnJycnJycl5dXV1dXV9dXV1dXXFxcXFxcXFxcXFycnJycnIAPzLNXl0yERIBOTkRMxEzMTABMwMjATMDIwIAxT5K" +
  "/kLFPkoFPf4fAeH+HwAAAgAUAAAFuAVIAA8AEgFfQPIRDg8PBBINEAwMBwcQBAMTFA0OEQ5gWRIREQEQBgUEDAcEDwEPX1kKARL0" +
  "FAHkFAHUFAHEFAG0FAGkFAGUFAGEFAF0FAFkFAFUFAFEFAE0FAEkFAEUFAEEFAH0FAHkFAHUFAHEFAG0FAGkFAGUFAGEFAF0FAFk" +
  "FAFUFAFEFAE0FAEkFAEUFAEEFAE59BQB5BQB1BQBxBQBtBQBpBQBlBQBhBQBdBQBVBQBRBQBNBQBJBQBBBQB1BQBwBQBArAUAaAU" +
  "AZAUAYAUAXAUAVAUAUAUATAUASAUARAUAeAUAcAUAaAUAZAUAYAUAXAUAVAUAU8UAV1dXV1dXV1dcXFxcXFxcXFxcV9xcXJycnJy" +
  "cnJycnJycnJyXl1dXV1dXV1dXV1dXV1dXV1xcXFxcXFxcXFxcXFxcXFxAD8zKxEAMzMzGD8zMxI5LzMrAC4zERIBFzkRMxESOTkR" +
  "MxE5OTEwJRUhNTcBMwEXFSE1NwMhAwEDIQHN/keYAcm+Aduq/cm0hf3whwGL5gHTNTU1GwT4+wgbNTUbAYP+fQRo/XUAAAMAO//6" +
  "BPIFPQAIABIAJgDdQJMJIgAcBQ4OFRUfHCIEKCclEGBZJRIfBQwFDGBZDwUBCwMFBRgTGBZfWRgEYFkYAxMVX1kTEqAoAZAoAYAo" +
  "AXAoAWAoAUAoAeAoAZ8oAYAoAWAoAVAoAUAoASAoAd8oAcAoAWAoATAoASAoAQAoATrPKAFQKAEQKAHwKAGQKAEAKAHgKAHQKAGg" +
  "KAFwKAFQKAFAKAFdXV1dXV1xcXFycnJeXV1dXV1dcXFxcXFxcXJycnJycgA/KwAYPysrERIAORgvX15dKxESADkYPysREgEXOREz" +
  "ETMRMxEzMTABNCYjIxEzMjYTNCYjIxEWMzI2BTU3ESc1ITIWFRQGBxYWFRQEISUDvpqtz9uimWW8z/CKnKuq/BisrAJl/+yRg7XG" +
  "/vX/AP5UA/h7cP4FgP4WjYP9zAaR5TUbBJ4aNZekdqYcE62IwccGAAACAEj/7ANxA8EAGwAlAG1APxEIJSUEIAwMGQQDJyYlIgoi" +
  "UVkYFRERHFBZDxEfEQIMAxERAAgKFgcEUFkHFQAVUFkAEIAnAV8nAUAnAYAnAV1xcnIAPysAGD8rABg/MxI5L19eXSsREgA5KxEA" +
  "MxESARc5ETMRMxEzMzEwATIWFREXFSEnBiMiETQ2Njc3NTQmIyIHByM1NgEHBgYVFDMyNjcB0ZqRdf7+E3Kx8UmgmI1HSmRTIjii" +
  "AQCDhl+PRGMyA8F+gv2FGS1ecgEYXntBAwSTYVwvdc0j/h4EBV5usB8YAAACAAD/7AOyBY0ACwAdAIBAURIHBx0AFx0XHh8aCVBZ" +
  "GhYGEhIUFANRWRQQDwxQWQ8AQB8BgB8BAB8BOZAfARAfAeAfAcAfAbAfAZAfAYAfAWAfAUAfAcAfAYAfAWAfASAfAV1dXV1xcXFx" +
  "cXFxcnJeXV1yAD8rABg/KxEAMxEzGD8rERIBOTkRMxEzETMxMAE0JiMiBgcRFjMyNgEnNSERFAc2MzIWFRQCIyImJwL+gIY7dBpU" +
  "dYp8/YuJAS8GZJjAzeHVVs9OAfC4tBUM/RcQ2AQuGC3+sDaQTuns/f75Jh8AAQAAAAcBUgBUAIsABgACABAALwBcAAACwwPGAAMA" +
  "AQAAAAAAAACVAWwCGQKLAvwAAQAAAAE7I194vPVfDzz1ABkIAAAAAADIRNDOAAAAANr/SO37pv2TCjoH2gAAAAkAAQAAAAAAAAY5" +
  "AAACAAAAA0QAfwXHABQFVgA7A40ASAQAAAAAAQAAByH+RQBXCqr7pvrfCjoAAQAAAAAAAAAAAAAAAAAAAAcAAwRcAZAABQAABZoF" +
  "MwAAASUFmgUzAAADoABkAaQBBQICBgMFBAUCAwQAAAADAAAAAAAAAAAAAAAATU9OTwBAACAAoAWM/kYBMwchAbtgAAG/3/cAAAOs" +
  "BT0AAAAgAAQAAAADAAMBAQEBAQUDAwECAQEAGAXsC8AA+Aj/AAgACP/+AAkACv/+AAoACv/+AAsAC//9AAwADP/9AA0ADP/9AA4A" +
  "Df/9AA8ADf/8ABAAD//8ABEAD//8ABIAEP/8ABMAEP/7ABQAEf/7ABUAEv/7ABYAFP/7ABcAFP/6ABgAFf/6ABkAF//6ABoAF//6" +
  "ABsAGP/5ABwAGv/5AB0AGv/5AB4AG//5AB8AHP/5ACAAHP/4ACEAHf/4ACIAH//4ACMAIP/4ACQAIP/3ACUAIf/3ACYAIv/3ACcA" +
  "Iv/3ACgAJP/2ACkAJf/2ACoAJv/2ACsAJ//2ACwAKP/1AC0AKf/1AC4AKv/1AC8AKv/1ADAAK//0ADEALP/0ADIALf/0ADMALf/0" +
  "ADQAL//zADUAMP/zADYAMP/zADcAMf/zADgAMv/yADkAM//yADoANf/yADsANf/yADwANv/yAD0ANv/xAD4AN//xAD8AOP/xAEAA" +
  "Ov/xAEEAOv/wAEIAO//wAEMAPP/wAEQAPf/wAEUAPf/vAEYAP//vAEcAQP/vAEgAQP/vAEkAQf/uAEoAQv/uAEsAQ//uAEwARP/u" +
  "AE0ARf/tAE4ARv/tAE8AR//tAFAAR//tAFEASP/sAFIASv/sAFMASv/sAFQAS//sAFUATP/rAFYATf/rAFcATf/rAFgAT//rAFkA" +
  "UP/rAFoAUf/qAFsAUf/qAFwAUv/qAF0AU//qAF4AVP/pAF8AVf/pAGAAVv/pAGEAV//pAGIAV//oAGMAWP/oAGQAWv/oAGUAW//o" +
  "AGYAW//nAGcAXP/nAGgAXf/nAGkAXf/nAGoAX//mAGsAYP/mAGwAYf/mAG0AYf/mAG4AYv/lAG8AY//lAHAAZP/lAHEAZf/lAHIA" +
  "Zv/kAHMAZ//kAHQAZ//kAHUAaP/kAHYAaf/kAHcAa//jAHgAa//jAHkAbP/jAHoAbf/jAHsAbv/iAHwAbv/iAH0AcP/iAH4Acf/i" +
  "AH8Acf/hAIAAcv/hAIEAc//hAIIAdP/hAIMAdf/gAIQAdv/gAIUAd//gAIYAeP/gAIcAeP/fAIgAef/fAIkAe//fAIoAe//fAIsA" +
  "fP/eAIwAff/eAI0Afv/eAI4Afv/eAI8AgP/dAJAAgf/dAJEAgv/dAJIAgv/dAJMAg//dAJQAhP/cAJUAhf/cAJYAhv/cAJcAh//e" +
  "AJgAiP/dAJkAiP/dAJoAif/dAJsAi//dAJwAjP/cAJ0AjP/cAJ4Ajf/cAJ8Ajv/cAKAAjv/bAKEAkP/bAKIAkf/bAKMAkv/bAKQA" +
  "kv/aAKUAk//aAKYAlP/aAKcAlv/aAKgAlv/ZAKkAl//ZAKoAmP/ZAKsAmf/aAKwAmf/aAK0Am//ZAK4AnP/ZAK8AnP/ZALAAnf/Z" +
  "ALEAnv/YALIAn//YALMAoP/YALQAof/YALUAov/XALYAo//XALcAo//XALgApP/XALkApv/WALoApv/WALsAp//WALwAqP/WAL0A" +
  "qf/VAL4Aqf/VAL8Aq//VAMAArP/VAMEArf/UAMIArf/UAMMArv/UAMQAsP/UAMUAsP/TAMYAsf/TAMcAs//TAMgAtP/TAMkAtP/T" +
  "AMoAtf/SAMsAtv/SAMwAt//SAM0AuP/SAM4Auf/RAM8Auv/RANAAuv/RANEAu//RANIAvP/QANMAvv/QANQAvv/QANUAv//QANYA" +
  "wP/PANcAwf/PANgAwf/PANkAw//PANoAxP/OANsAxP/OANwAxf/OAN0Axv/OAN4Ax//NAN8AyP/NAOAAyf/NAOEAyv/NAOIAy//M" +
  "AOMAy//MAOQAzP/MAOUAzv/MAOYAzv/MAOcAz//LAOgA0P/LAOkA0f/LAOoA0f/LAOsA0//KAOwA1P/KAO0A1f/KAO4A1f/KAO8A" +
  "1v/KAPAA1//KAPEA2P/KAPIA2f/KAPMA2v/JAPQA2//JAPUA2//JAPYA3P/JAPcA3v/IAPgA3//IAPkA3//IAPoA4P/IAPsA4f/H" +
  "APwA4f/HAP0A4//HAP4A5P/HAP8A5f/GAPgI/wAIAAj//gAJAAr//gAKAAr//gALAAv//QAMAAz//QANAAz//QAOAA3//QAPAA3/" +
  "/AAQAA///AARAA///AASABD//AATABD/+wAUABH/+wAVABL/+wAWABT/+wAXABT/+gAYABX/+gAZABf/+gAaABf/+gAbABj/+QAc" +
  "ABr/+QAdABr/+QAeABv/+QAfABz/+QAgABz/+AAhAB3/+AAiAB//+AAjACD/+AAkACD/9wAlACH/9wAmACL/9wAnACL/9wAoACT/" +
  "9gApACX/9gAqACb/9gArACf/9gAsACj/9QAtACn/9QAuACr/9QAvACr/9QAwACv/9AAxACz/9AAyAC3/9AAzAC3/9AA0AC//8wA1" +
  "ADD/8wA2ADD/8wA3ADH/8wA4ADL/8gA5ADP/8gA6ADX/8gA7ADX/8gA8ADb/8gA9ADb/8QA+ADf/8QA/ADj/8QBAADr/8QBBADr/" +
  "8ABCADv/8ABDADz/8ABEAD3/8ABFAD3/7wBGAD//7wBHAED/7wBIAED/7wBJAEH/7gBKAEL/7gBLAEP/7gBMAET/7gBNAEX/7QBO" +
  "AEb/7QBPAEf/7QBQAEf/7QBRAEj/7ABSAEr/7ABTAEr/7ABUAEv/7ABVAEz/6wBWAE3/6wBXAE3/6wBYAE//6wBZAFD/6wBaAFH/" +
  "6gBbAFH/6gBcAFL/6wBdAFP/6wBeAFT/6gBfAFX/6gBgAFb/6gBhAFf/6gBiAFf/6QBjAFj/6QBkAFr/6QBlAFv/6QBmAFv/6QBn" +
  "AFz/6QBoAF3/6QBpAF3/6QBqAF//6ABrAGD/6ABsAGH/6ABtAGH/6ABuAGL/5wBvAGP/5wBwAGT/5wBxAGX/5wByAGb/5gBzAGf/" +
  "5gB0AGf/5gB1AGj/5gB2AGn/5gB3AGv/5QB4AGv/5QB5AGz/5QB6AG3/5QB7AG7/5AB8AG7/5AB9AHD/5AB+AHH/5AB/AHH/4wCA" +
  "AHL/4wCBAHP/4wCCAHT/4wCDAHX/4gCEAHb/4gCFAHf/4gCGAHj/4gCHAHj/4QCIAHn/4QCJAHv/4QCKAHv/4QCLAHz/4ACMAH3/" +
  "4ACNAH7/4ACOAH7/4ACPAID/3wCQAIH/3wCRAIL/3wCSAIL/3wCTAIP/3wCUAIT/3gCVAIX/3gCWAIb/3gCXAIf/3gCYAIj/3QCZ" +
  "AIj/3QCaAIn/3QCbAIv/3QCcAIz/3ACdAIz/3ACeAI3/3ACfAI7/3ACgAI7/2wChAJD/2wCiAJH/2wCjAJL/2wCkAJL/2gClAJP/" +
  "2gCmAJT/2gCnAJb/2gCoAJb/2QCpAJf/2QCqAJj/2QCrAJj/2gCsAJn/2QCtAJv/2QCuAJz/2QCvAJz/2QCwAJ3/2QCxAJ7/2ACy" +
  "AJ//2ACzAKD/2AC0AKH/2AC1AKL/2AC2AKP/2AC3AKP/2AC4AKT/2AC5AKb/2AC6AKb/2AC7AKf/2AC8AKj/1wC9AKn/1wC+AKn/" +
  "1wC/AKv/1wDAAKz/1wDBAK3/1gDCAK3/1gDDAK7/1gDEALD/1gDFALD/1QDGALH/1ADHALP/1ADIALT/1ADJALT/1ADKALX/0wDL" +
  "ALb/0wDMALf/0wDNALj/0wDOALn/0gDPALr/0gDQALr/0gDRALv/0gDSALz/0QDTAL7/0QDUAL7/0QDVAL//0gDWAMD/0QDXAMH/" +
  "0QDYAMH/0QDZAMP/0QDaAMT/0ADbAMT/0ADcAMX/0ADdAMb/0ADeAMf/zwDfAMj/zwDgAMn/zwDhAMr/zwDiAMv/zgDjAMv/zgDk" +
  "AMz/zgDlAM7/zgDmAM7/zgDnAM//zQDoAND/zQDpANH/zQDqANH/zADrANP/ywDsANT/ywDtANX/ywDuANX/ywDvANb/ywDwANf/" +
  "ywDxANj/ywDyANn/zADzANr/ywD0ANv/ywD1ANv/ywD2ANz/ywD3AN7/ygD4AN//ygD5AN//ygD6AOD/ygD7AOH/yQD8AOH/yQD9" +
  "AOP/yQD+AOT/yQD/AOX/yAD4CP8ACAAI//4ACQAK//4ACgAK//4ACwAL//0ADAAM//0ADQAM//0ADgAN//0ADwAN//wAEAAP//wA" +
  "EQAP//wAEgAQ//wAEwAQ//sAFAAR//sAFQAS//sAFgAU//sAFwAU//oAGAAV//oAGQAX//oAGgAX//oAGwAY//kAHAAa//kAHQAa" +
  "//kAHgAb//kAHwAc//kAIAAc//gAIQAd//gAIgAf//gAIwAg//gAJAAg//cAJQAh//cAJgAi//cAJwAi//cAKAAk//YAKQAl//YA" +
  "KgAm//YAKwAn//YALAAo//UALQAp//UALgAr//UALwAq//UAMAAr//QAMQAs//QAMgAt//QAMwAt//QANAAv//MANQAw//MANgAw" +
  "//MANwAx//MAOAAy//IAOQAz//IAOgA1//IAOwA1//IAPAA2//IAPQA2//EAPgA3//EAPwA4//EAQAA6//EAQQA6//AAQgA7//AA" +
  "QwA8//AARAA9//AARQA9/+8ARgA//+8ARwBA/+8ASABA/+8ASQBB/+4ASgBC/+4ASwBD/+4ATABE/+4ATQBF/+0ATgBG/+0ATwBH" +
  "/+0AUABH/+0AUQBI/+wAUgBK/+wAUwBK/+wAVABL/+wAVQBM/+sAVgBN/+sAVwBN/+sAWABP/+sAWQBQ/+sAWgBR/+oAWwBR/+oA" +
  "XABS/+sAXQBT/+sAXgBU/+oAXwBV/+oAYABW/+oAYQBX/+oAYgBX/+kAYwBY/+kAZABa/+kAZQBb/+kAZgBb/+kAZwBc/+kAaABd" +
  "/+kAaQBd/+kAagBf/+gAawBg/+gAbABh/+gAbQBh/+gAbgBi/+cAbwBj/+cAcABk/+cAcQBl/+cAcgBm/+YAcwBn/+YAdABn/+YA" +
  "dQBo/+YAdgBp/+YAdwBr/+UAeABr/+UAeQBs/+UAegBt/+UAewBu/+QAfABu/+QAfQBw/+QAfgBx/+QAfwBx/+MAgABy/+MAgQBz" +
  "/+MAggB0/+MAgwB1/+IAhAB2/+IAhQB3/+IAhgB4/+IAhwB4/+EAiAB5/+EAiQB7/+EAigB7/+EAiwB8/+AAjAB9/+AAjQB+/+AA" +
  "jgB+/+AAjwCA/98AkACB/98AkQCC/98AkgCC/98AkwCD/98AlACE/94AlQCF/94AlgCG/94AlwCH/94AmACI/90AmQCI/90AmgCJ" +
  "/90AmwCL/90AnACM/9wAnQCM/9wAngCN/9wAnwCO/9wAoACO/9sAoQCQ/9sAogCR/9sAowCS/9sApACS/9oApQCT/9oApgCU/9oA" +
  "pwCW/9oAqACW/9kAqQCX/9kAqgCY/9kAqwCZ/9oArACZ/9kArQCb/9kArgCc/9kArwCc/9kAsACd/9kAsQCe/9gAsgCf/9gAswCg" +
  "/9gAtACh/9gAtQCi/9cAtgCj/9gAtwCj/9gAuACk/9gAuQCm/9gAugCm/9gAuwCn/9gAvACo/9cAvQCp/9cAvgCp/9cAvwCr/9cA" +
  "wACs/9cAwQCt/9YAwgCt/9YAwwCu/9YAxACv/9YAxQCw/9UAxgCx/9QAxwCz/9QAyAC0/9QAyQC0/9QAygC1/9MAywC2/9MAzAC3" +
  "/9MAzQC4/9MAzgC5/9IAzwC6/9IA0AC6/9IA0QC7/9IA0gC8/9EA0wC+/9EA1AC+/9EA1QC//9IA1gDA/9EA1wDB/9EA2ADB/9EA" +
  "2QDD/9EA2gDE/9AA2wDE/9AA3ADF/9AA3QDG/9AA3gDH/88A3wDI/88A4ADJ/88A4QDK/88A4gDL/84A4wDL/84A5ADM/84A5QDO" +
  "/84A5gDO/84A5wDP/80A6ADQ/80A6QDR/80A6gDR/8wA6wDT/8sA7ADU/8sA7QDV/8sA7gDV/8sA7wDW/8sA8ADX/8sA8QDY/8sA" +
  "8gDZ/8wA8wDa/8sA9ADb/8sA9QDb/8sA9gDc/8sA9wDe/8oA+ADf/8oA+QDf/8oA+gDg/8oA+wDh/8kA/ADh/8kA/QDj/8kA/gDk" +
  "/8kA/wDl/8gAAAAYAAAADAsJCQMFCAcFBQAAAAwJCQMFCQgFBgAAAA0KCgMGCggGBwAAAA8MDAQFCwoHBwAAABAMDAQFCwoHCAAA" +
  "ABENDQQFCwsHCAAAABMPDwUIDQwICgAAABUQEAUIDg4JCgAAABgTEwYKERALDAAAABsVFQcKExIMDgAAAB0XFwcKFBMMDgAAACAZ" +
  "GQgNFhUOEAAAACEaGggNFxYPEAAAACUdHQkPGRkQEgAAACohIQsRHhsTFAAAAC4kJAwSIB4VFwAAADInJw0UIyEWGAAAADYqKg4W" +
  "JiQYGwAAADotLQ8XKSYaHQAAAEM0NBEbLy0eIgAAAEs6OhMeNTIhJgAAAFNBQRUjOzglKgAAAFxISBcmQj0pLgAAAGROThkoSEIs" +
  "MgAAAAAAAAEAAwABAAAADAAEAEAAAAAMAAgAAgAEACAAIgBCAGIAoP//AAAAIAAiAEEAYQCg////4f/g/8L/pP9hAAEAAAAAAAAA" +
  "AAAAAABAR1taWVhVVFNSUVBPTk1MS0pJSEdGRURDQkFAPz49PDs6OTg3NjUxMC8uLSwoJyYlJCMiIR8YFBEQDw4NCwoJCAcGBQQD" +
  "AgEALCCwAWBFsAMlIBFGYSNFI2FILSwgRRhoRC0sRSNGYLAgYSCwRmCwBCYjSEgtLEUjRiNhsCBgILAmYbAgYbAEJiNISC0sRSNG" +
  "YLBAYSCwZmCwBCYjSEgtLEUjRiNhsEBgILAmYbBAYbAEJiNISC0sARAgPAA8LSwgRSMgsM1EIyC4AVpRWCMgsI1EI1kgsO1RWCMg" +
  "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" +
  "VQEuAT0AgAAfAT0AAQE+AFUBPAA9ATsAVQAfATsAPwE7AE8BOwCPATsABAE7AAEBPgBVATAAPQEvAFUBLwABAT4AVQEtAD0BLABV" +
  "AM8BLAABASwAAQE+AFUBPwA9AT4AVQFKAAEBSABVAUcAAQFIAFUBRgA9AUUAVQFFAAEBSABVAUkAPQFIAFUAYAEHAAEAPwEHAAEA" +
  "vwEEQLMB4P0Bz/0BIP0Bf/sBUPsBgPKQ8gLx8Ckfr/C/8AJP71/vr+8DMO8BD+8BCADtEO1Q7WDtcO2g7QYKD+wBDADrARHj4Dgf" +
  "3z3dVd493FUA3QE8AN0w3VDdgN2w3QXdAQNV3AMWHxDAIMAwwHDAgMDQwODA8MAIgL6QvgK9vC8fD7wfvAIfs0+zf7MDYKgBD6gf" +
  "qAJQm2CbApCcAQ+cH5wvnAOamS4fmUceH5eWJx/glvCWArj/wLOWDRFGvAFPAUwAPQAfAU6zA/8fr0EVAU0AAQAPAU0AHwFNAC8B" +
  "TQBPAU0AbwFNAI8BTQAGAA8BTAAfAUwALwFMQDgDX5UBC5IbkiuSe5KLkgVwhoCGkIYDgIWQhQKvdr92AnNQKR9vbisfbkcqHxkz" +
  "GFUHMwNVBgP/H7j/wEBJYiUoRmBfQB9fUCkfW1owH1pHKR8TMxJVBQEDVQQzA1UPAx8DPwNPA28DjwO/AwcIUlAeH1FQHh/gUPBQ" +
  "AkBQCQxGD08fTy9PA7j/4EBlSyEoRmBKcEqASgNJRikfSEc4Hw9HH0cvR89H30fvRwZfRwGfRwGfRq9Gv0YDQEYpL0ZARh4hRhxI" +
  "G1UWMxVVEQEPVRAzD1UCAQBVATMAVS8P/w8CDw9fD38PAw8APwACgBYBBQG4AZCxVFMrK0u4B/9SS7AIUFuwAYiwJVOwAYiwQFFa" +
  "sAaIsABVWltYsQEBjlmFjY0AQh1LsDJTWLBgHVlLsGRTWLBAHVlLsIBTWLAQHbEWAEJZc3N0KysrKysrASsrc3N0dSsrcwArdSt0" +
  "KytecysrKwErKwArKysrKysBKysAK3MBc3MAc3Nzc3QrKwErcysrK3NzAHNzcwFzAHMrAXNzACsrc15zKysBK15zXnMAXnNec3Nz" +
  "AXMrcwBzc3NzcwFzc3MAKysrKysrK3MrKysrcysrKysrKysrcxheBY0AFQBIBT0ADwBwBT0ADwAAAAAAAAAAAAAAAAAAA6wAGQCZ" +
  "AAD/7AAAAAD/7AAAAAD/7AAA/kz/+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAmACmALQAjQDZAF0AAAAAAAAARgBQAGkAdQDZAAAAAAAAAAAAAAAAAMEA0QBp" +
  "AAAAAABQAFoAqgCKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsALgAWgAAAAAAUABgAI8AmQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "UACXALMAxwDZAAAAAAAAAAAAAABQAG0AewCNALUA2QExAMkAAAFvAPIBCACBAMUAuADyATEATQAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "Ag4AAABmAAAAAABmAAAAAAAAAAAAAALbAJsCiwBKAuQAAACZAGYAAAIvAhAAxACcAV4AAAF0AEYAjQAAAAAAAABGADwAAAAAAAAA" +
  "AAAAAAAAAAAAAIcAfQAAAFMAaAB2AIcAAAAAAAAFPfzaAAn/8wCPAH0ASgCCAEEAbAAAAAAAAAAAAAAAvAGfAwoAAANUAJ8ApgDB" +
  "AAAAAAAvAAAAAAAAAAAHSANqArYCAv2TAAAAkQBnAJEAYQHZAAACjQNBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1UADQEpAyUACQAAAAAAAAAAAAAAAAAAAAAAAAAAAjQAD/76" +
  "AjL/9AMkAAoAVf/wAAACNAAP/vr/S//zA2H+bgRfBBwFPQTLAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaRBG0ACgAA/+X+" +
  "e/5kBU4FpgC1AKgAAAAAAAcAWgADAAEECQAAAHQAAAADAAEECQABAAoAdAADAAEECQACAA4AfgADAAEECQADAC4AjAADAAEECQAE" +
  "ABoAugADAAEECQAFABgA1AADAAEECQAGABoA7ABEAGkAZwBpAHQAaQB6AGUAZAAgAGQAYQB0AGEAIABjAG8AcAB5AHIAaQBnAGgA" +
  "dAAgACgAYwApACAAMgAwADEAMAAtADIAMAAxADIAIABHAG8AbwBnAGwAZQAgAEMAbwByAHAAbwByAGEAdABpAG8AbgAuAFQAaQBu" +
  "AG8AcwBSAGUAZwB1AGwAYQByADEALgAyADMAOwBNAE8ATgBPADsAVABpAG4AbwBzAC0AUgBlAGcAdQBsAGEAcgBUAGkAbgBvAHMA" +
  "IABSAGUAZwB1AGwAYQByAFYAZQByAHMAaQBvAG4AIAAxAC4AMgAzAFQAaQBuAG8AcwAtAFIAZQBnAHUAbABhAHIAAwAAAAAAAP8h" +
  "AGQAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAMACgAOABAAB///AA8AAQAAAAwAAAAAAAAAAgABAAAABgABAAAAAQAAAA4AIgAKAAEA" +
  "LAADY3lybAAwZ3JlawA0bGF0bgA4AANrZXJuAChrZXJuAChrZXJuACgAAgAIAAEAGgAgAAAAJAAAACgAAAAAAAEAAAABADIABAAA" +
  "AAIAJgAsAAD//wABAAAAAP//AAEAAQAA//8AAQACAAEAA/+PAAEAAf+PAAEAAgABAAMAAAABAAAADgAKAAwAAAAAAARjeXJsABpn" +
  "cmVrABpoZWJyABpsYXRuABoAAAAA"
}

///|
fn hint_parity_font_cousine_hint_subset_b64() -> String {
  "AAEAAAARAQAABAAQR0RFRgARAAEAABQ4AAAAFkdQT1MAGQAMAAAUUAAAABBHU1VCMpBPYAAAFGAAAAAmT1MvMnbiqgIAAAJMAAAA" +
  "YGNtYXAADADFAAACrAAAADRjdnQgLTdfYwAAEdwAAADaZnBnbZ42FtQAAALgAAAOFWdhc3AAAAAQAAAUMAAAAAhnbHlmYD7nIgAA" +
  "ARwAAACkaGVhZBbsMqIAAAHoAAAANmhoZWEIwfziAAACKAAAACRobXR4Bb8AfwAAAiAAAAAGbG9jYQBSAAAAAAHgAAAABm1heHAF" +
  "MRHVAAABwAAAACBuYW1lGOQzMwAAErgAAAFYcG9zdP4mAFUAABQQAAAAIHByZXCOKCukAAAQ+AAAAOEAAQDyAAAEFQROABUAW0uw" +
  "GVBYQAsOAAIBAAFMFQECShtACxUBAgMOAAIBAAJMWUuwGVBYQBEAAAACYQMBAgJITQABAUYBThtAFQACAkhNAAAAA2EAAwNOTQAB" +
  "AUYBTlm2JhQTIQQKGisBJiMiBhURIxE0JiczFhczPgIzMhcEFXBkoca0GxmrKAgFMmCEX2hmA5YT8rv+BAK9TM5jinBwaTURAAAB" +
  "AAAAAgEiAEgAWwAGAAIBcAJAAI0AAALgDhUAAwABAAAAAABSAAAAAQAAAAE64eL9XF9fDzz1AAcIAAAAAADaDCH1AAAAANuui1/8" +
  "Jf2ZBfEH2QAAAAYAAgAAAAAAAATNAH8A8gAAAAEAAAap/ZkAAATN/CX6egXxAAEAAAAAAAAAAAAAAAAAAAABAAQEzQGQAAUAAAUz" +
  "BM0AAACaBTMEzQAAAs0AZgISAAACBwQJAgIFAgQEAAAAAQAAAAAAAAAAAAAAAEdPT0cAQAByAHIE5/5+AAAGqQJnYAABv9/3AAAE" +
  "OgVFAAAAIAAAAAAAAgAAAAMAAAAUAAMAAQAAABQABAAgAAAABAAEAAEAAABy//8AAABy////jwABAAAAALAALCCwAFVYRVkgIEu4" +
  "AA5RS7AGU1pYsDQbsChZYGYgilVYsAIlYbkIAAgAY2MjYhshIbAAWbAAQyNEsgABAENgQi2wASywIGBmLbACLCMhIyEtsAMsIGSz" +
  "AxQVAEJDsBNDIGBgQrECFENCsSUDQ7ACQ1R4ILAMI7ACQ0NhZLAEUHiyAgICQ2BCsCFlHCGwAkNDsg4VAUIcILACQyNCshMBE0Ng" +
  "QiOwAFBYZVmyFgECQ2BCLbAELLADK7AVQ1gjISMhsBZDQyOwAFBYZVkbIGQgsMBQsAQmWrIoAQ1DRWNFsAZFWCGwAyVZUltYISMh" +
  "G4pYILBQUFghsEBZGyCwOFBYIbA4WVkgsQENQ0VjRWFksChQWCGxAQ1DRWNFILAwUFghsDBZGyCwwFBYIGYgiophILAKUFhgGyCw" +
  "IFBYIbAKYBsgsDZQWCGwNmAbYFlZWRuwAiWwDENjsABSWLAAS7AKUFghsAxDG0uwHlBYIbAeS2G4EABjsAxDY7gFAGJZWWRhWbAB" +
  "K1lZI7AAUFhlWVkgZLAWQyNCWS2wBSwgRSCwBCVhZCCwB0NQWLAHI0KwCCNCGyEhWbABYC2wBiwjISMhsAMrIGSxB2JCILAII0Kw" +
  "BkVYG7EBDUNFY7EBDUOwBmBFY7AFKiEgsAhDIIogirABK7EwBSWwBCZRWGBQG2FSWVgjWSFZILBAU1iwASsbIbBAWSOwAFBYZVkt" +
  "sAcssAlDK7IAAgBDYEItsAgssAkjQiMgsAAjQmGwAmJmsAFjsAFgsAcqLbAJLCAgRSCwDkNjuAQAYiCwAFBYsEBgWWawAWNgRLAB" +
  "YC2wCiyyCQ4AQ0VCKiGyAAEAQ2BCLbALLLAAQyNEsgABAENgQi2wDCwgIEUgsAErI7AAQ7AEJWAgRYojYSBkILAgUFghsAAbsDBQ" +
  "WLAgG7BAWVkjsABQWGVZsAMlI2FERLABYC2wDSwgIEUgsAErI7AAQ7AEJWAgRYojYSBksCRQWLAAG7BAWSOwAFBYZVmwAyUjYURE" +
  "sAFgLbAOLCCwACNCsw0MAANFUFghGyMhWSohLbAPLLECAkWwZGFELbAQLLABYCAgsA9DSrAAUFggsA8jQlmwEENKsABSWCCwECNC" +
  "WS2wESwgsBBiZrABYyC4BABjiiNhsBFDYCCKYCCwESNCIy2wEixLVFixBGREWSSwDWUjeC2wEyxLUVhLU1ixBGREWRshWSSwE2Uj" +
  "eC2wFCyxABJDVVixEhJDsAFhQrARK1mwAEOwAiVCsQ8CJUKxEAIlQrABFiMgsAMlUFixAQBDYLAEJUKKiiCKI2GwECohI7ABYSCK" +
  "I2GwECohG7EBAENgsAIlQrACJWGwECohWbAPQ0ewEENHYLACYiCwAFBYsEBgWWawAWMgsA5DY7gEAGIgsABQWLBAYFlmsAFjYLEA" +
  "ABMjRLABQ7AAPrIBAQFDYEItsBUsALEAAkVUWLASI0IgRbAOI0KwDSOwBmBCILAUI0IgYLABYbcYGAEAEQATAEJCQopgILAUQ2Cw" +
  "FCNCsRQIK7CLKxsiWS2wFiyxABUrLbAXLLEBFSstsBgssQIVKy2wGSyxAxUrLbAaLLEEFSstsBsssQUVKy2wHCyxBhUrLbAdLLEH" +
  "FSstsB4ssQgVKy2wHyyxCRUrLbArLCMgsBBiZrABY7AGYEtUWCMgLrABXRshIVktsCwsIyCwEGJmsAFjsBZgS1RYIyAusAFxGyEh" +
  "WS2wLSwjILAQYmawAWOwJmBLVFgjIC6wAXIbISFZLbAgLACwDyuxAAJFVFiwEiNCIEWwDiNCsA0jsAZgQiBgsAFhtRgYAQARAEJC" +
  "imCxFAgrsIsrGyJZLbAhLLEAICstsCIssQEgKy2wIyyxAiArLbAkLLEDICstsCUssQQgKy2wJiyxBSArLbAnLLEGICstsCgssQcg" +
  "Ky2wKSyxCCArLbAqLLEJICstsC4sIDywAWAtsC8sIGCwGGAgQyOwAWBDsAIlYbABYLAuKiEtsDAssC8rsC8qLbAxLCAgRyAgsA5D" +
  "Y7gEAGIgsABQWLBAYFlmsAFjYCNhOCMgilVYIEcgILAOQ2O4BABiILAAUFiwQGBZZrABY2AjYTgbIVktsDIsALEAAkVUWLEOBkVC" +
  "sAEWsDEqsQUBFUVYMFkbIlktsDMsALAPK7EAAkVUWLEOBkVCsAEWsDEqsQUBFUVYMFkbIlktsDQsIDWwAWAtsDUsALEOBkVCsAFF" +
  "Y7gEAGIgsABQWLBAYFlmsAFjsAErsA5DY7gEAGIgsABQWLBAYFlmsAFjsAErsAAWtAAAAAAARD4jOLE0ARUqIS2wNiwgPCBHILAO" +
  "Q2O4BABiILAAUFiwQGBZZrABY2CwAENhOC2wNywuFzwtsDgsIDwgRyCwDkNjuAQAYiCwAFBYsEBgWWawAWNgsABDYbABQ2M4LbA5" +
  "LLECABYlIC4gR7AAI0KwAiVJiopHI0cjYSBYYhshWbABI0KyOAEBFRQqLbA6LLAAFrAXI0KwBCWwBCVHI0cjYbEMAEKwC0MrZYou" +
  "IyAgPIo4LbA7LLAAFrAXI0KwBCWwBCUgLkcjRyNhILAGI0KxDABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYFGllCQiMgsApDIIoj" +
  "RyNHI2EjRmCwBkOwAmIgsABQWLBAYFlmsAFjYCCwASsgiophILAEQ2BkI7AFQ2FkUFiwBENhG7AFQ2BZsAMlsAJiILAAUFiwQGBZ" +
  "ZrABY2EjICCwBCYjRmE4GyOwCkNGsAIlsApDRyNHI2FgILAGQ7ACYiCwAFBYsEBgWWawAWNgIyCwASsjsAZDYLABK7AFJWGwBSWw" +
  "AmIgsABQWLBAYFlmsAFjsAQmYSCwBCVgZCOwAyVgZFBYIRsjIVkjICCwBCYjRmE4WS2wPCywABawFyNCICAgsAUmIC5HI0cjYSM8" +
  "OC2wPSywABawFyNCILAKI0IgICBGI0ewASsjYTgtsD4ssAAWsBcjQrADJbACJUcjRyNhsABUWC4gPCMhG7ACJbACJUcjRyNhILAF" +
  "JbAEJUcjRyNhsAYlsAUlSbACJWG5CAAIAGNjIyBYYhshWWO4BABiILAAUFiwQGBZZrABY2AjLiMgIDyKOCMhWS2wPyywABawFyNC" +
  "ILAKQyAuRyNHI2EgYLAgYGawAmIgsABQWLBAYFlmsAFjIyAgPIo4LbBALCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQrLbBBLCMg" +
  "LkawAiVGsBdDWFIbUFlYIDxZLrEwARQrLbBCLCMgLkawAiVGsBdDWFAbUllYIDxZIyAuRrACJUawF0NYUhtQWVggPFkusTABFCst" +
  "sEMssDorIyAuRrACJUawF0NYUBtSWVggPFkusTABFCstsEQssDsriiAgPLAGI0KKOCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQr" +
  "sAZDLrAwKy2wRSywABawBCWwBCYgICBGI0dhsAwjQi5HI0cjYbALQysjIDwgLiM4sTABFCstsEYssQoEJUKwABawBCWwBCUgLkcj" +
  "RyNhILAGI0KxDABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYFGllCQiMgR7AGQ7ACYiCwAFBYsEBgWWawAWNgILABKyCKimEgsARD" +
  "YGQjsAVDYWRQWLAEQ2EbsAVDYFmwAyWwAmIgsABQWLBAYFlmsAFjYbACJUZhOCMgPCM4GyEgIEYjR7ABKyNhOCFZsTABFCstsEcs" +
  "sQA6Ky6xMAEUKy2wSCyxADsrISMgIDywBiNCIzixMAEUK7AGQy6wMCstsEkssAAVIEewACNCsgABARUUEy6wNiotsEossAAVIEew" +
  "ACNCsgABARUUEy6wNiotsEsssQABFBOwNyotsEwssDkqLbBNLLAAFkUjIC4gRoojYTixMAEUKy2wTiywCiNCsE0rLbBPLLIAAEYr" +
  "LbBQLLIAAUYrLbBRLLIBAEYrLbBSLLIBAUYrLbBTLLIAAEcrLbBULLIAAUcrLbBVLLIBAEcrLbBWLLIBAUcrLbBXLLMAAABDKy2w" +
  "WCyzAAEAQystsFksswEAAEMrLbBaLLMBAQBDKy2wWyyzAAABQystsFwsswABAUMrLbBdLLMBAAFDKy2wXiyzAQEBQystsF8ssgAA" +
  "RSstsGAssgABRSstsGEssgEARSstsGIssgEBRSstsGMssgAASCstsGQssgABSCstsGUssgEASCstsGYssgEBSCstsGcsswAAAEQr" +
  "LbBoLLMAAQBEKy2waSyzAQAARCstsGosswEBAEQrLbBrLLMAAAFEKy2wbCyzAAEBRCstsG0sswEAAUQrLbBuLLMBAQFEKy2wbyyx" +
  "ADwrLrEwARQrLbBwLLEAPCuwQCstsHEssQA8K7BBKy2wciywABaxADwrsEIrLbBzLLEBPCuwQCstsHQssQE8K7BBKy2wdSywABax" +
  "ATwrsEIrLbB2LLEAPSsusTABFCstsHcssQA9K7BAKy2weCyxAD0rsEErLbB5LLEAPSuwQistsHossQE9K7BAKy2weyyxAT0rsEEr" +
  "LbB8LLEBPSuwQistsH0ssQA+Ky6xMAEUKy2wfiyxAD4rsEArLbB/LLEAPiuwQSstsIAssQA+K7BCKy2wgSyxAT4rsEArLbCCLLEB" +
  "PiuwQSstsIMssQE+K7BCKy2whCyxAD8rLrEwARQrLbCFLLEAPyuwQCstsIYssQA/K7BBKy2whyyxAD8rsEIrLbCILLEBPyuwQCst" +
  "sIkssQE/K7BBKy2wiiyxAT8rsEIrLbCLLLILAANFUFiwBhuyBAIDRVgjIRshWVlCK7AIZbADJFB4sQUBFUVYMFktAAAAAEu4AMhS" +
  "WLEBAY5ZsAG5CAAIAGNwsQAHQrdqWk4ANCQGACqxAAdCQA5fCFMGQwg5BSkIGwcGCiqxAAdCQA5nBlkESwY+AzEGIgUGCiqxAA1C" +
  "vxgAFQARAA6ACoAHAAAGAAsqsQATQr8AQABAAEAAQABAAEAABgALKrkAAwAARLEkAYhRWLBAiFi5AAMAZESxKAGIUVi4CACIWLkA" +
  "AwAARFkbsScBiFFYugiAAAEEQIhjVFi5AAMAAERZWVlZWUAOYQZVBEUGOwMrBh0FBg4quAH/hbAEjbECAESzBWQGAEREAAAAAAAA" +
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAvQC9AIUAhQVFAAAEOgAA/lcFWv/sBE7/7P5X" +
  "AL0AvQCFAIUFRf/sBcwEOv/s/lcFWv/sBcwETv/s/lcAuAC4AKoAqgTLAAD+fwTL/+z+fwC9AL0AhQCFBUUAAAXMBDoAAP5XBVr/" +
  "7AXMBE7/7P5XAIAAgABeAF4DjgJz/3j+YQOOAoH/av5hAIAAgABeAF4FzAHqBf8E5QHqAL4F2wHcBf8E8wHcAL4AAAAAAAcAWgAD" +
  "AAEECQAAAF4AAAADAAEECQABAA4AXgADAAEECQACAA4AbAADAAEECQADACIAegADAAEECQAEAB4AnAADAAEECQAFAEQAugADAAEE" +
  "CQAGAA4AXgBDAG8AcAB5AHIAaQBnAGgAdAAgADIAMAAxADAAIABHAG8AbwBnAGwAZQAgAEkAbgBjAC4AIABBAGwAbAAgAFIAaQBn" +
  "AGgAdABzACAAUgBlAHMAZQByAHYAZQBkAC4AQwBvAHUAcwBpAG4AZQBSAGUAZwB1AGwAYQByADEALgAyADMAOwBHAE8ATwBHADsA" +
  "QwBvAHUAcwBpAG4AZQBDAG8AdQBzAGkAbgBlACAAUgBlAGcAdQBsAGEAcgBWAGUAcgBzAGkAbwBuACAAMQAuADIAMwA7ACAAdAB0" +
  "AGYAYQB1AHQAbwBoAGkAbgB0ACAAKAB2ADEALgA4AC4AMgApAAMAAAAAAAD+IwBUAAAAAQAAAAAAAAAAAAAAAAAAAAAAAQAB//8A" +
  "DwABAAAADAAAAAAAAAABAAAAAgABAAEAAAABAAAACgAMAA4AAAAAAAAAAQAAAA4ACgAMAAAAAAADY3lybAAUaGVicgAUbGF0bgAU" +
  "AAAAAAAA"
}

///|
test "hint: ignore hdmx when back compat enabled" {
  let font = golden_font(hint_parity_font_tinos_subset_b64())
  let gid = font.charmap().glyph_id((34).reinterpret_as_uint()).unwrap()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(
    outlines0,
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
    HintingOptions::default(),
  ).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let metrics = glyph
    .draw(DrawSettings::hinted(hinter, false), NullPen::new())
    .unwrap()
  let ok = (metrics.advance_width.unwrap() - 7.0).abs() <= 0.000001
  inspect(ok, content="true")
  inspect(
    hint_parity_hdmx_width(font, 16, gid).unwrap_or(-1) == 5,
    content="true",
  )
}

///|
test "hint: use hdmx when back compat disabled" {
  let font = golden_font(hint_parity_font_tinos_subset_b64())
  let gid = font.charmap().glyph_id((34).reinterpret_as_uint()).unwrap()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(
    outlines0,
    @moon_skrifa.Size::new(16.0),
    @moon_skrifa.LocationRef::default(),
    HintingOptions::new(Engine::Interpreter, Target::Mono),
  ).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let metrics = glyph
    .draw(DrawSettings::hinted(hinter, false), NullPen::new())
    .unwrap()
  inspect(
    hint_parity_hdmx_width(font, 16, gid).unwrap_or(-1) == 5,
    content="true",
  )
  let ok = (metrics.advance_width.unwrap() - 5.0).abs() <= 0.000001
  inspect(ok, content="true")
}

///|
test "hint: round advance when prep disables hinting" {
  // Build a minimal glyf font where the prep program disables hinting via
  // the INSTRCTRL instruction (selector=1, value=1).
  let prep = Bytes::from_array(
    Array::from_fixed_array([
      (0xB1).to_byte(), // PUSHB[2]
      (1).to_byte(), // value
      (1).to_byte(), // selector
      (0x8E).to_byte(), // INSTCTRL
    ]).op_as_view(),
  )
  let glyph0 = Bytes::from_array(Array::new().op_as_view())
  let glyph1 = glyf_outline_test_glyph_simple_quad()
  let glyf_out : Array[Byte] = Array::new()
  for b in glyph0.iter() {
    glyf_out.push(b)
  }
  let off0 = 0
  let off1 = off0 + glyph0.length()
  for b in glyph1.iter() {
    glyf_out.push(b)
  }
  let off2 = off1 + glyph1.length()
  let loca = glyf_outline_test_make_loca_long(
    Array::from_fixed_array([off0, off1, off2]),
  )
  let sfnt = glyf_outline_test_build_sfnt(
    Array::from_fixed_array([
      (0x6D617870, glyf_outline_test_make_maxp(2)), // "maxp"
      (0x68656164, glyf_outline_test_make_head_long_loca_with_upem(2048)), // "head"
      (0x68686561, glyf_outline_test_make_hhea(2)), // "hhea"
      (
        0x686D7478, // "hmtx"
        glyf_outline_test_make_hmtx(
          Array::from_fixed_array([0, 836]),
          Array::from_fixed_array([0, 0]),
        ),
      ),
      (0x6C6F6361, loca), // "loca"
      (0x676C7966, Bytes::from_array(glyf_out.op_as_view())), // "glyf"
      (0x70726570, prep), // "prep"
    ]),
  )
  let font = @moon_skrifa.FontRef::new(sfnt).unwrap()
  let size = @moon_skrifa.Size::new(16.0)
  let loc = @moon_skrifa.LocationRef::default()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(
    outlines0,
    size,
    loc,
    HintingOptions::default(),
  ).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(1).unwrap()
  let metrics = glyph
    .draw(DrawSettings::hinted(hinter, false), NullPen::new())
    .unwrap()
  inspect(metrics.advance_width.unwrap() == 7.0, content="true")
  let metrics = glyph
    .draw(DrawSettings::unhinted(size, loc), NullPen::new())
    .unwrap()
  let ok = (metrics.advance_width.unwrap() - 6.53125).abs() <= 0.000001
  inspect(ok, content="true")
}

///|
test "hint: fractional font size rounds MPPEM" {
  let font = golden_font(hint_parity_font_cousine_hint_subset_b64())
  let gid : @moon_skrifa.GlyphId = (1).to_uint16()
  let size = @moon_skrifa.Size::new(24.8)
  let loc = @moon_skrifa.LocationRef::default()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter0 = HintingInstance::new(
    outlines0,
    size,
    loc,
    HintingOptions::default(),
  )
  match hinter0 {
    Err(DrawError::HintingFailed(e)) =>
      inspect("HintingFailed " + hint_parity_hint_error_tag(e), content="Ok")
    Err(_) => inspect("Err", content="Ok")
    Ok(hinter) => {
      let outlines = OutlineGlyphCollection::from_font(font)
      let glyph = outlines.get(gid).unwrap()
      let pen = SvgPen::new()
      glyph.draw(DrawSettings::hinted(hinter, false), pen).unwrap() |> ignore
      inspect(
        pen.to_string(),
        content="M12.65625,11.015625 Q11.296875,11.421875 10.078125,11.421875 Q8.140625,11.421875 6.9375,9.9375 Q5.734375,8.46875 5.734375,6.1875 L5.734375,0 L3.5625,0 L3.5625,8.421875 Q3.5625,9.328125 3.390625,10.5625 Q3.234375,11.8125 2.9375,13 L5,13 Q5.484375,11.34375 5.578125,10 L5.640625,10 Q6.25,11.25 6.828125,11.828125 Q7.40625,12.40625 8.203125,12.703125 Q9.015625,13 10.15625,13 Q11.421875,13 12.65625,13 Z",
      )
    }
  }
}

///|
test "hint: composite glyf instructions (vazirmatn gid=2)" {
  let font = golden_font(font_vazirmatn_var_trimmed_b64())
  let gid : @moon_skrifa.GlyphId = (2).to_uint16()
  let size = @moon_skrifa.Size::new(16.0)
  let coords : Array[@moon_skrifa.NormalizedCoord] = Array::from_fixed_array([0])
  let loc = @moon_skrifa.LocationRef::new(coords.op_as_view())
  let opts = Engine::Interpreter.into()
  let outlines0 = OutlineGlyphCollection::from_font(font)
  let hinter = HintingInstance::new(outlines0, size, loc, opts).unwrap()
  let outlines = OutlineGlyphCollection::from_font(font)
  let glyph = outlines.get(gid).unwrap()
  let pen = SvgPen::new()
  match
    glyph.draw(
      DrawSettings::hinted(hinter, false).with_path_style(PathStyle::FreeType),
      pen,
    ) {
    Err(DrawError::HintingFailed(e)) =>
      inspect("HintingFailed " + hint_parity_hint_error_tag(e), content="Ok")
    Err(DrawError::GlyphNotFound(_)) => inspect("GlyphNotFound", content="Ok")
    Err(DrawError::NoSources) => inspect("NoSources", content="Ok")
    Err(DrawError::HarfBuzzHintingUnsupported) =>
      inspect("HarfBuzzHintingUnsupported", content="Ok")
    Err(_) => inspect("Err", content="Ok")
    Ok(_) =>
      inspect(
        pen.to_string(),
        content="M5.53125,10.375 L1.765625,0 L0.234375,0 L4.5625,11.375 L5.5625,11.375 Z M8.6875,0 L4.921875,10.375 L4.890625,11.375 L5.890625,11.375 L10.234375,0 Z M8.5,4.21875 L8.5,2.984375 L2.109375,2.984375 L2.109375,4.21875 Z M4.578125,14 L6.078125,11.703125 L4.84375,11.703125 L2.828125,14 Z",
      )
  }
}
