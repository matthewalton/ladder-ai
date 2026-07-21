import SwiftUI

/// The CV's identity block — name, headline, contact — edited in place.
/// Fields commit on submit or focus loss.
struct ProfileHeaderView: View {
    @Bindable var store: ProfileStore
    let profile: Profile

    @State private var name: String
    @State private var headline: String
    @State private var email: String
    @State private var phone: String
    @State private var location: String
    @State private var link: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, headline, email, phone, location, link
    }

    init(store: ProfileStore, profile: Profile) {
        self.store = store
        self.profile = profile
        _name = State(initialValue: profile.name)
        _headline = State(initialValue: profile.headline)
        _email = State(initialValue: profile.contact.email)
        _phone = State(initialValue: profile.contact.phone)
        _location = State(initialValue: profile.contact.location)
        _link = State(initialValue: profile.contact.link)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.trailNarrative(.largeTitle))
                .foregroundStyle(Color.ink)
                .focused($focusedField, equals: .name)
                .onSubmit(commitIdentity)

            TextField("Headline — e.g. Senior iOS Engineer", text: $headline)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(Color.inkSoft)
                .focused($focusedField, equals: .headline)
                .onSubmit(commitIdentity)

            HStack(spacing: 12) {
                contactField("Email", text: $email, field: .email)
                contactField("Phone", text: $phone, field: .phone)
                contactField("Location", text: $location, field: .location)
                contactField("Link", text: $link, field: .link)
            }
            .padding(.top, 2)
        }
        .onChange(of: focusedField) { previous, _ in
            guard previous != nil else { return }
            commitIdentity()
            commitContact()
        }
    }

    private func contactField(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .trailMetadata()
            .foregroundStyle(Color.inkSoft)
            .focused($focusedField, equals: field)
            .onSubmit(commitContact)
    }

    private func commitIdentity() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = profile.name
            return
        }
        guard trimmed != profile.name || headline != profile.headline else { return }
        try? store.updateIdentity(name: trimmed, headline: headline)
        name = profile.name
    }

    private func commitContact() {
        let contact = ContactInfo(email: email, phone: phone, location: location, link: link)
        guard contact != profile.contact else { return }
        try? store.updateContact(contact)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    try! store.updateContact(ContactInfo(email: "alex@example.com", location: "London"))
    return ProfileHeaderView(store: store, profile: profile)
        .padding()
        .background(Color.paper)
}
