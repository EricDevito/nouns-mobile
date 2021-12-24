//
//  TraitPickerItem.swift
//  Nouns
//
//  Created by Mohammed Ibrahim on 2021-12-24.
//

import SwiftUI
import UIComponents
import Services

extension NounPlayground {
  
  struct TraitPickerItem: View {
    let image: String
    
    init(image: String) {
      self.image = image
    }
    
    var body: some View {
      Image(nounTraitName: image)
        .interpolation(.none)
        .resizable()
        .frame(width: 72, height: 72, alignment: .top)
        .background(Color.componentSoftGrey)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct TraitSelectedModifier: ViewModifier {

  func body(content: Content) -> some View {
    content
      .background(Color.black.opacity(0.05))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.componentNounsBlack, lineWidth: 2)
      }
  }
}

extension NounPlayground.TraitPickerItem {
  
  func selected(_ condition: Bool) -> some View {
    if condition {
      return AnyView(modifier(TraitSelectedModifier()))
    } else {
      return AnyView(self)
    }
  }
}
